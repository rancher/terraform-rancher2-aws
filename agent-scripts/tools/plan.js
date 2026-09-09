#!/usr/bin/env node
import path from 'path';
import process from 'process';
import { fileURLToPath } from 'url';
import {
  calculatePlanChecksum,
  findLatestActivePlan,
  readPlan,
  updatePlan,
  validatePlan,
  validatePlanContent,
  checkActivePlan,
} from '../lib/plan.js';
import { resolveTargetDir, deleteFileSafe } from '../lib/file.js';

export {
  calculatePlanChecksum,
  findLatestActivePlan,
  readPlan,
  updatePlan,
  validatePlan,
  validatePlanContent,
  checkActivePlan,
};

function showHelp() {
  console.log(`Usage: plan.js <command> [options]

Commands:
  find                       Find and print the path to the latest active plan
  read                       Read and print the contents of the latest active plan
  update <content>           Update the latest active plan with the provided content
  checksum                   Calculate and print the SHA-256 checksum of the latest active plan
  validate                   Validate the format and requirements of the latest active plan
  help, -h, --help           Show this help message
`);
  process.exit(0);
}

async function main() {
  const command = process.argv[2];
  const targetDir = await resolveTargetDir();

  try {
    if (!command || command === 'help' || command === '-h' || command === '--help') {
      showHelp();
    } else if (command === 'find') {
      const planPath = await findLatestActivePlan(targetDir);
      if (planPath) {
        console.log(planPath);
      } else {
        console.error('❌ No active plan found.');
        process.exit(1);
      }
    } else if (command === 'read') {
      const content = await readPlan(targetDir);
      if (content !== null) {
        console.log(content);
      } else {
        console.error('❌ Failed to read plan or no active plan found.');
        process.exit(1);
      }
    } else if (command === 'update') {
      const content = process.argv[3];
      if (content === undefined) {
        console.error('Error: update requires <content>');
        process.exit(1);
      }
      const success = await updatePlan(targetDir, content);
      if (success) {
        console.log('✅ Plan successfully updated.');
      } else {
        console.error('❌ Failed to update plan or no active plan found.');
        process.exit(1);
      }
    } else if (command === 'checksum') {
      const checksum = await calculatePlanChecksum(targetDir);
      if (checksum) {
        console.log(checksum);
      } else {
        console.error('❌ Failed to calculate checksum or no active plan found.');
        process.exit(1);
      }
    } else if (command === 'validate') {
      const validation = await validatePlan(targetDir);
      if (validation.valid) {
        console.log('✅ Plan format is valid.');
      } else {
        console.error('❌ Plan validation failed:');
        validation.errors.forEach((err) => console.error(`  - ${err}`));
        await deleteFileSafe(path.join(targetDir, 'plan-approval.json'));
        await deleteFileSafe(path.join(targetDir, 'plan-approval.json.sig'));
        await deleteFileSafe(path.join(targetDir, 'review-approval.json'));
        await deleteFileSafe(path.join(targetDir, 'require-ask-user.flag'));
        process.exit(1);
      }
    } else {
      console.error(`Unknown command: ${command}`);
      process.exit(1);
    }
  } catch (err) {
    console.error(`Plan command failed: ${err.message}`);
    process.exit(1);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((err) => {
    console.error('::error::Fatal Plan Tool Error:', err.stack || err.message);
    process.exit(1);
  });
}
