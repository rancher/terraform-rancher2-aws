#!/usr/bin/env node
import process from 'process';
import path from 'path';
import { fileURLToPath } from 'url';
import { parseTestLogs, runAgentTests, runLint, runPreReviewTests, runProductTests } from '../lib/test.js';
import { resolveTargetDir, deleteFileSafe } from '../lib/file.js';
import { revokeSignature } from '../lib/approval.js';
import { setLock } from '../lib/state.js';

export { parseTestLogs, runAgentTests, runLint, runPreReviewTests, runProductTests };

function showHelp() {
  console.log(`Usage: test.js <command> [options]

Commands:
  pre-review                 Run the full workspace lint and test suite (pre-review gate)
  product                    Run only the product tests
  agent                      Run only the agent-script tests
  lint                       Run only the workspace linter
  parse-logs                 Parse gotestsum JSON log files to generate a structured outcome report
  help, -h, --help           Show this help message
`);
  process.exit(0);
}

async function main() {
  const command = process.argv[2];

  try {
    if (!command || command === 'help' || command === '-h' || command === '--help') {
      showHelp();
    } else if (command === 'pre-review') {
      console.log('Running pre-review tests...');
      const result = await runPreReviewTests();
      if (result.success) {
        console.log(result.output);
        console.log('✅ Pre-review tests passed successfully.');
        process.exit(0);
      } else {
        console.error(result.failureOutput);
        console.error('❌ Pre-review tests failed.');
        const targetDir = await resolveTargetDir();
        await revokeSignature(targetDir, 'review-approval.json');
        await deleteFileSafe(path.join(targetDir, 'require-ask-user.flag'));
        await setLock(targetDir, false);
        process.exit(1);
      }
    } else if (command === 'product') {
      console.log('Running product tests...');
      const result = await runProductTests();
      if (result.success) {
        console.log(result.stdout || result.output || '');
        console.log('✅ Product tests passed successfully.');
        process.exit(0);
      } else {
        console.error(result.stdout || '');
        console.error(result.stderr || '');
        console.error('❌ Product tests failed.');
        process.exit(1);
      }
    } else if (command === 'agent') {
      console.log('Running agent-script tests...');
      const result = await runAgentTests();
      if (result.success) {
        console.log(result.stdout || result.output || '');
        console.log('✅ Agent script tests passed successfully.');
        process.exit(0);
      } else {
        console.error(result.stdout || '');
        console.error(result.stderr || '');
        console.error('❌ Agent script tests failed.');
        process.exit(1);
      }
    } else if (command === 'lint') {
      console.log('Running workspace lint...');
      const result = await runLint();
      if (result.success) {
        console.log(result.stdout || result.output || '');
        console.log('✅ Workspace lint passed successfully.');
        process.exit(0);
      } else {
        console.error(result.stdout || '');
        console.error(result.stderr || '');
        console.error('❌ Workspace lint failed.');
        process.exit(1);
      }
    } else if (command === 'parse-logs') {
      const options = {
        file: null,
        noColor: false,
        failedOnly: false,
        passedOnly: false,
      };
      for (let i = 3; i < process.argv.length; i++) {
        const arg = process.argv[i];
        if (arg === '-f' || arg === '--file') {
          options.file = process.argv[++i];
        } else if (arg === '--no-color') {
          options.noColor = true;
        } else if (arg === '--failed-only') {
          options.failedOnly = true;
        } else if (arg === '--passed-only') {
          options.passedOnly = true;
        }
      }
      const result = parseTestLogs(options);
      console.log(result.output);
      process.exit(result.success ? 0 : 1);
    } else {
      console.error(`Unknown command: ${command}`);
      process.exit(1);
    }
  } catch (err) {
    console.error(`Test command failed: \n${err.message}`);
    if (err.stdout) {
      console.error(`\nStdout:\n${err.stdout.toString()}`);
    }
    if (err.stderr) {
      console.error(`\nStderr:\n${err.stderr.toString()}`);
    }
    process.exit(1);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((err) => {
    console.error('::error::Fatal Test Tool Error:', err.stack || err.message);
    process.exit(1);
  });
}
