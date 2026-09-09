#!/usr/bin/env node
import process from 'process';
import { fileURLToPath } from 'url';
import {
  checkAndRevokeStaleGates,
  generateAndSignApproval,
  handleApproval,
  handleCommitApproval,
  handlePlanApproval,
  handleReviewApproval,
  readApprovalData,
  revokeAllSignatures,
  revokeSignature,
  verifyCommitGate,
  verifyPlanGate,
  verifyReviewGate,
  verifyProactiveReview,
  extractCommitMessage,
  healApprovalState,
} from '../lib/approval.js';
import { resolveTargetDir } from '../lib/file.js';

export {
  checkAndRevokeStaleGates,
  generateAndSignApproval,
  handleApproval,
  handleCommitApproval,
  handlePlanApproval,
  handleReviewApproval,
  readApprovalData,
  revokeAllSignatures,
  revokeSignature,
  verifyCommitGate,
  verifyPlanGate,
  verifyReviewGate,
  verifyProactiveReview,
  extractCommitMessage,
  healApprovalState,
};

function showHelp() {
  console.log(`Usage: approval.js <command> [options]

Commands:
  sign <fileName> <signingKeyFile> <envelopeJson>  Generate and sign an approval file
  verify-plan                                      Verify the Plan Gate (Gate 1)
  verify-review <diffHash> <planHash>              Verify the Review Gate (Gate 2)
  verify-commit <diffHash>                         Verify the Commit Gate (Gate 3)
  revoke-all                                       Revoke all active signatures
  revoke <fileName>                                Delete a specific approval file
  read <fileName> [key]                            Read data from an approval file
  handle --type <type> --signing-key <file> [--prompt-text <text>] [--target-dir <dir>] Handle approval sequence
  heal-approval <targetDir> [gate]                 Centralized self-healing routine to purge invalid gates
  help, -h, --help                                 Show this help message
`);
  process.exit(0);
}

async function main() {
  const command = process.argv[2];
  const targetDir = await resolveTargetDir();

  try {
    if (!command || command === 'help' || command === '-h' || command === '--help') {
      showHelp();
    } else if (command === 'sign') {
      const fileName = process.argv[3];
      const signingKeyFile = process.argv[4];
      const envelopeJson = process.argv[5];
      if (!fileName || !signingKeyFile || !envelopeJson) {
        console.error('Error: sign requires <fileName>, <signingKeyFile>, and <envelopeJson>');
        process.exit(1);
      }
      let envelope;
      try {
        envelope = JSON.parse(envelopeJson);
      } catch (parseErr) {
        console.error(`Error: Failed to parse envelope JSON: ${parseErr.message}`);
        process.exit(1);
      }
      await generateAndSignApproval(targetDir, fileName, signingKeyFile, envelope);
      console.log(`✅ Successfully generated and signed ${fileName}`);
    } else if (command === 'verify-plan') {
      const hash = await verifyPlanGate(targetDir);
      if (hash) {
        console.log(`✅ Plan Gate verified. Hash: ${hash}`);
      } else {
        console.error('❌ Plan Gate verification failed. Revoking plan signatures.');
        await healApprovalState(targetDir, 'plan');
        process.exit(1);
      }
    } else if (command === 'verify-review') {
      const diffHash = process.argv[3];
      const planHash = process.argv[4];
      if (!diffHash || !planHash) {
        console.error('Error: verify-review requires <diffHash> and <planHash>');
        process.exit(1);
      }
      const passed = await verifyReviewGate(targetDir, diffHash, planHash);
      if (passed) {
        console.log('✅ Review Gate verified.');
      } else {
        console.error('❌ Review Gate verification failed. Revoking review signature.');
        await healApprovalState(targetDir, 'review');
        process.exit(1);
      }
    } else if (command === 'verify-commit') {
      const diffHash = process.argv[3];
      if (!diffHash) {
        console.error('Error: verify-commit requires <diffHash>');
        process.exit(1);
      }
      const passed = await verifyCommitGate(targetDir, diffHash);
      if (passed) {
        console.log('✅ Commit Gate verified.');
      } else {
        console.error('❌ Commit Gate verification failed. Revoking commit signature.');
        await healApprovalState(targetDir, 'commit');
        process.exit(1);
      }
    } else if (command === 'revoke-all') {
      await revokeAllSignatures(targetDir);
      console.log('✅ All signatures revoked.');
    } else if (command === 'revoke') {
      const fileName = process.argv[3];
      if (!fileName) {
        console.error('Error: revoke requires <fileName>');
        process.exit(1);
      }
      await revokeSignature(targetDir, fileName);
      console.log(`✅ Revoked signature for ${fileName}`);
    } else if (command === 'read') {
      const fileName = process.argv[3];
      const key = process.argv[4];
      if (!fileName) {
        console.error('Error: read requires <fileName>');
        process.exit(1);
      }
      const data = await readApprovalData(targetDir, fileName, key);
      if (data) {
        console.log(typeof data === 'object' ? JSON.stringify(data, null, 2) : data);
      } else {
        console.error(`❌ Data not found in ${fileName}`);
        process.exit(1);
      }
    } else if (command === 'handle') {
      const { parseArgs } = await import('util');
      const { values } = parseArgs({
        args: process.argv.slice(3),
        options: {
          type: { type: 'string' },
          'target-dir': { type: 'string' },
          'pub-key': { type: 'string' },
          'signing-key': { type: 'string' },
          'prompt-text': { type: 'string', default: '' },
        },
      });
      const tDir = values['target-dir'] || targetDir;
      const keyFile = values['signing-key'] || values['pub-key'];
      await handleApproval(values.type, tDir, keyFile, values['prompt-text'] || '');
    } else if (command === 'heal-approval') {
      const tDir = process.argv[3] || targetDir;
      const gateType = process.argv[4] || 'all';
      await healApprovalState(tDir, gateType);
    } else {
      console.error(`Unknown command: ${command}`);
      process.exit(1);
    }
  } catch (err) {
    console.error(`Approval command failed: ${err.message}`);
    process.exit(1);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((err) => {
    console.error('::error::Fatal Approval Tool Error:', err.stack || err.message);
    process.exit(1);
  });
}
