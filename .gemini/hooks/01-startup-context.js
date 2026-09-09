#!/usr/bin/env node

import path from 'path';
import { resolveTargetDir } from '../../agent-scripts/tools/file.js';
import {
  discardStdin,
  verifyNixEnvironment,
  loadFrameworkContext,
  initializeWorkspaceFlags,
  protectExcludeFiles,
  buildCombinedContext,
  buildStartupOutput,
} from './01-startup/startupLogic.js';

const hookName = path.basename(process.argv[1] || '01-startup-context.js');
const introLog = `🔒 Hook: ${hookName} - Loading hook context...`;
console.error(introLog);

const originalLog = console.log;
let hasLogged = false;

console.log = function (msg) {
  if (hasLogged) {
    return;
  }
  try {
    const parsed = JSON.parse(msg);
    if (parsed.systemMessage) {
      console.error(parsed.systemMessage);
    }
    const exitLog = `🔒 Hook: ${hookName} - Done.`;
    console.error(exitLog);

    const msgs = [introLog];
    if (parsed.systemMessage) {
      msgs.push(parsed.systemMessage);
    }
    msgs.push(exitLog);
    parsed.systemMessage = msgs.join('\n');

    if (!parsed.decision) {
      parsed.decision = 'allow';
    }

    originalLog(JSON.stringify(parsed, null, 2));
    hasLogged = true;
  } catch (err) {
    console.error(err.message || err);
    originalLog(msg);
  }
};

process.on('exit', (code) => {
  if (!hasLogged) {
    const exitMsg = `🔒 Hook Error (${hookName}): Silent early exit detected with code ${code}.`;
    console.error(exitMsg);
    process.stdout.write(
      JSON.stringify({
        decision: 'deny',
        systemMessage: `${introLog}\n${exitMsg}`,
      }) + '\n',
    );
    hasLogged = true;
  }
});

process.on('uncaughtException', (err) => {
  const errMsg = `🔒 Hook Error (${hookName}): Unhandled exception - ${err.message || err}`;
  console.error(errMsg);
  if (!hasLogged) {
    process.stdout.write(
      JSON.stringify({
        decision: 'deny',
        systemMessage: `${introLog}\n${errMsg}`,
      }) + '\n',
    );
    hasLogged = true;
  }
  process.exit(1);
});

async function main() {
  // 1. Consume stdin inputs cleanly
  discardStdin();

  // 2. Resolve temporary directory and setup workspace-level state flags
  const targetDir = await resolveTargetDir();
  await initializeWorkspaceFlags(targetDir);

  // 3. Diagnose the Nix hermetic shell execution environment
  const nixEnv = verifyNixEnvironment();

  // 4. Load repository-wide architectural specifications
  const frameworkContext = await loadFrameworkContext();

  // 5. Lock ignore/exclude files to read-only mode to prevent tampering
  await protectExcludeFiles();

  // 6. Build the combined markdown context block of mandates and guides
  const combinedContext = buildCombinedContext(nixEnv.text, frameworkContext);

  // 7. Output final JSON context structured payload to stdout
  buildStartupOutput(combinedContext, nixEnv.active);
}

main().catch((err) => {
  console.error('::error::Fatal Startup Context Hook Error:', err.stack || err.message);
  process.exit(1);
});
