#!/usr/bin/env node
import fs from 'fs';
import os from 'os';
import path from 'path';
import { fileURLToPath } from 'url';
import { executeFileSafe, mkdtempSafe, writeFileSafe, deleteFileSafe } from './tools/file.js';

// Open/Closed Principle compliant: Load models dynamically via environment variables with a safe fallback
const models = process.env.GEMINI_EXERCISE_MODELS
  ? process.env.GEMINI_EXERCISE_MODELS.split(',').map((m) => m.trim())
  : ['gemini-3.1-pro-preview', 'gemini-3.5-flash', 'gemini-2.5-pro', 'gemini-3.1-flash-lite'];

const subagent = '@heads_down_coder'; // Using a generic agent to exercise the model
const prompt =
  'Perform a simple sanity check: output "Hello World" and a brief confirmation. Also acknowledge the contents of the text file placed in your sandbox.';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function main() {
  const logFilePath = path.join(__dirname, 'exercise-agents.log');
  let logContent = `Agent Exercise Log - ${new Date().toISOString()}\n=========================================\n`;

  const log = (msg) => {
    console.log(msg);
    logContent += msg + '\n';
  };
  const logError = (msg) => {
    console.error(msg);
    logContent += msg + '\n';
  };

  // Create a unique, randomized sandbox subdirectory to prevent symlink race conditions (Facade pattern compliant)
  const uniqueSandbox = await mkdtempSafe(path.join(os.tmpdir(), 'gemini-exercise-'));
  const dummyFile = path.join(uniqueSandbox, 'dummy.txt');
  await writeFileSafe(dummyFile, 'Hello from the auto-sandbox file inclusion test!');

  const cliPath = path.join(__dirname, 'tools', 'gemini.js');

  const summary = {
    passed: [],
    failed: [],
  };

  for (const model of models) {
    log(`\n🚀 Exercising model: ${model} via CLI (auto-sandbox)...`);
    try {
      const args = [
        '--prompt',
        prompt,
        '--subagent',
        subagent,
        '--retry',
        '3',
        '--model',
        model,
        '--sandbox-file',
        dummyFile,
      ];

      // Using safe Level-2 file execution façade instead of duplicating process logic
      const stdout = await executeFileSafe(cliPath, args);
      if (stdout) {
        log(stdout);
      }
      log(`✅ ${model} completed successfully.`);
      summary.passed.push(model);
    } catch (err) {
      if (err.stdout) {
        log(err.stdout);
      }
      if (err.stderr) {
        logError(err.stderr);
      }
      logError(`❌ ${model} failed: ${err.message}`);

      let reason = err.message ? err.message.split('\n')[0] : 'Unknown error';
      if (err.stderr) {
        const quotaMatch = err.stderr.match(/TerminalQuotaError:\s*(.*)/);
        if (quotaMatch) {
          reason = quotaMatch[1].trim();
        } else {
          const errLine = err.stderr.split('\n').find((l) => l.includes('Error:'));
          if (errLine) {
            reason = errLine.trim();
          }
        }
      }
      summary.failed.push({ model, reason });
    }
  }

  log(`%_CLEANUP_%`);
  log(`🧹 Cleaning up unique sandbox directory: ${uniqueSandbox}`);
  try {
    await deleteFileSafe(dummyFile);
    fs.rmSync(uniqueSandbox, { recursive: true, force: true });
  } catch (err) {
    logError(`⚠️ Failed to remove sandbox directory ${uniqueSandbox}: ${err.message}`);
  }

  log('\n=========================================');
  log('📊 Execution Summary');
  log('=========================================');
  log(`Total Models Tested: ${models.length}`);
  log(`✅ Passed: ${summary.passed.length}`);
  if (summary.passed.length > 0) {
    log(`   - ${summary.passed.join('\n   - ')}`);
  }
  log(`❌ Failed: ${summary.failed.length}`);
  if (summary.failed.length > 0) {
    log(`   - ${summary.failed.map((f) => `${f.model} (${f.reason})`).join('\n   - ')}`);
  }
  log('=========================================\n');

  await writeFileSafe(logFilePath, logContent, { encoding: 'utf-8' });
  console.log(`\n📝 Full output logged to: ${logFilePath}`);
}

main().catch((err) => {
  console.error(`❌ Fatal Exercise Agents Error: ${err.stack || err.message}`);
  process.exit(1);
});
