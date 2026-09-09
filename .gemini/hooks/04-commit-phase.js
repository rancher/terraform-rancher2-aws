#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { resolveTargetDir } from '../../agent-scripts/tools/file.js';
import { preCommitPhaseInterruption, beforeAskUserCommit, afterAskUserCommit } from './04-commit/commitLogic.js';

const hookName = path.basename(process.argv[1] || '04-commit-phase.js');
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

function restoreSshAgent() {
  if (process.env.SSH_AUTH_SOCK) {
    return;
  }
  if (process.platform === 'darwin') {
    try {
      const tmpDir = '/private/tmp';
      const dirs = fs.readdirSync(tmpDir).filter((d) => d.startsWith('com.apple.launchd.'));
      for (const d of dirs) {
        const listenerPath = path.join(tmpDir, d, 'Listeners');
        if (fs.existsSync(listenerPath)) {
          process.env.SSH_AUTH_SOCK = listenerPath;
          console.error(`🔒 Hook Info: Dynamically restored SSH_AUTH_SOCK to ${listenerPath}`);
          return;
        }
      }
    } catch (err) {
      console.error(`🔒 Hook Warning: Failed to restore SSH agent dynamically: ${err.message}`);
    }
  }
}

async function main() {
  restoreSshAgent();
  let inputData;
  try {
    inputData = JSON.parse(fs.readFileSync(0, 'utf-8'));
  } catch (err) {
    console.error('Failed to parse stdin JSON in 04-commit-phase:', err.message || err);
    console.log(
      JSON.stringify({
        decision: 'allow',
        systemMessage: '🔒 Hook Notification: Failed to parse input, allowing execution by default.',
      }),
    );
    process.exit(0);
  }

  const targetDir = await resolveTargetDir();
  const args = process.argv.slice(2);

  if (args.includes('--before-ask')) {
    await beforeAskUserCommit(inputData, targetDir);
  } else if (args.includes('--after-ask')) {
    await afterAskUserCommit(inputData, targetDir);
  } else {
    await preCommitPhaseInterruption(inputData, targetDir);
    console.log(
      JSON.stringify({
        decision: 'allow',
        systemMessage: '🔒 Hook Notification: Pre-commit phase check complete, execution allowed.',
      }),
    );
    process.exit(0);
  }
}

main().catch((err) => {
  console.error('::error::Fatal Commit Phase Hook Error:', err.stack || err.message);
  process.exit(1);
});
