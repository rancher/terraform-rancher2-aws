#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { resolveTargetDir } from '../../agent-scripts/tools/file.js';
import { clearPrePlanFlag, beforeExitPlanMode, afterExitPlanMode } from './02-plan/facilitatePlanning.js';
import { beforeAskUserPlan, afterAskUserPlan } from './02-plan/askUserLogic.js';
import { prePlanPhaseInterruption, verifyGateArtifactProtection } from './02-plan/interruption.js';

const hookName = path.basename(process.argv[1] || '02-plan-phase.js');
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
  let inputData;
  try {
    inputData = JSON.parse(fs.readFileSync(0, 'utf-8'));
  } catch (err) {
    console.error('Failed to parse stdin JSON:', err);
    console.log(
      JSON.stringify({
        decision: 'allow',
        systemMessage: '🔒 Hook Notification: Failed to parse input, allowing execution by default.',
      }),
    );
    process.exit(0);
  }

  // Enforce Gate Artifact Tamper Protection
  verifyGateArtifactProtection(inputData);

  const targetDir = await resolveTargetDir();
  if (!fs.existsSync(targetDir)) {
    fs.mkdirSync(targetDir, { recursive: true });
  }

  const args = process.argv.slice(2);
  if (args.includes('--enter-proof')) {
    await clearPrePlanFlag(targetDir);
  } else if (args.includes('--verify-exit')) {
    await beforeExitPlanMode(inputData, targetDir);
  } else if (args.includes('--clear-plan-mode')) {
    await afterExitPlanMode(inputData, targetDir);
  } else if (args.includes('--before-ask-proof')) {
    await beforeAskUserPlan(inputData, targetDir);
  } else if (args.includes('--ask-proof')) {
    await afterAskUserPlan(inputData, targetDir);
  } else {
    await prePlanPhaseInterruption(inputData, targetDir);
  }
}

main().catch((err) => {
  console.error('::error::Fatal Plan Phase Hook Error:', err.stack || err.message);
  process.exit(1);
});
