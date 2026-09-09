import { execFile } from 'child_process';
import crypto from 'crypto';
import fs, { promises as fsPromises } from 'fs';
import os from 'os';
import path from 'path';
import { promisify } from 'util';
import {
  calculateFileHash,
  deleteFileSafe,
  extractPlanContent,
  readFileSafe,
  savePlanContent,
  writeFileSafe,
} from './file.js';
import {
  calculateDiffHash,
  gitBranchShowCurrent,
  gitDiff,
  gitRevParseShowToplevel,
  runAutomatedCommitAndPush,
} from './git.js';
import { findLatestActivePlan } from './plan.js';
import { readState, updateState } from './state.js';

const execFileAsync = promisify(execFile);

function execFileWithInput(cmd, args, options = {}, inputBuffer = null) {
  return new Promise((resolve, reject) => {
    const child = execFile(cmd, args, { ...options }, (error, stdout, stderr) => {
      if (error) {
        reject(error);
      } else {
        resolve({ stdout, stderr });
      }
    });

    if (inputBuffer && child.stdin) {
      child.stdin.write(inputBuffer);
      child.stdin.end();
    }
  });
}

function logGating(level, message, data = {}) {
  const formattedMessage = `${message} ${Object.keys(data).length > 0 ? JSON.stringify(data) : ''}`.trim();
  if (level === 'error') {
    console.log(`::error::${formattedMessage}`);
  } else if (level === 'warn') {
    console.log(`::warning::${formattedMessage}`);
  } else {
    console.log(`::notice::${formattedMessage}`);
  }
}

export async function generateAndSignApproval(targetDir, fileName, signingKeyFile, envelope) {
  const approvalFile = path.join(targetDir, fileName);
  const signatureFile = path.join(targetDir, `${fileName}.sig`);

  await deleteFileSafe(approvalFile);
  await deleteFileSafe(signatureFile);

  await writeFileSafe(approvalFile, JSON.stringify(envelope, null, 2));
  const privKeyFile = signingKeyFile.endsWith('.pub') ? signingKeyFile.slice(0, -4) : signingKeyFile;
  const pubKeyPath = privKeyFile + '.pub';

  const hasPubKey = fs.existsSync(pubKeyPath);
  if (!hasPubKey || !process.env.SSH_AUTH_SOCK) {
    throw new Error(
      `Missing key pair or active SSH agent. Public key (${pubKeyPath}) must exist, and SSH_AUTH_SOCK must be active.`,
    );
  }

  await execFileAsync('ssh-keygen', ['-Y', 'sign', '-f', privKeyFile, '-n', 'gemini', approvalFile]);
}

export async function verifyPlanGate(targetDir) {
  const planApprovalFile = path.join(targetDir, 'plan-approval.json');
  const sigFile = path.join(targetDir, 'plan-approval.json.sig');
  const pubKeyFile = path.resolve(os.homedir(), '.gemini/ssh-key.pub');

  const planData = await readFileSafe(planApprovalFile);
  const pubKeyContent = await readFileSafe(pubKeyFile);
  if (!planData || !fs.existsSync(sigFile) || !pubKeyContent) {
    return null;
  }

  try {
    const allowedSignersFile = path.join(targetDir, 'allowed_signers');
    await writeFileSafe(allowedSignersFile, `gemini ${pubKeyContent.trim()}`);

    const fileBuffer = await fsPromises.readFile(planApprovalFile);

    await execFileWithInput(
      'ssh-keygen',
      ['-Y', 'verify', '-f', allowedSignersFile, '-I', 'gemini', '-n', 'gemini', '-s', sigFile],
      {
        stdio: ['pipe', 'ignore', 'ignore'],
      },
      fileBuffer,
    );

    let content;
    try {
      content = JSON.parse(planData);
    } catch (err) {
      logGating('error', 'Failed to parse plan approval JSON', { message: err.message });
      content = {};
    }

    if (content.status !== 'approved') {
      return null;
    }

    const activePlan = await findLatestActivePlan(targetDir);
    if (!activePlan) {
      return null;
    }

    return content.plan_hash;
  } catch (err) {
    logGating('error', 'verifyPlanGate failed', { message: err.message });
    return null;
  }
}

export async function verifyReviewGate(targetDir, expectedDiffHash, expectedPlanHash) {
  const reviewApprovalFile = path.join(targetDir, 'review-approval.json');

  const reviewData = await readFileSafe(reviewApprovalFile);
  if (!reviewData) {
    return false;
  }

  try {
    let content;
    try {
      content = JSON.parse(reviewData);
    } catch (err) {
      logGating('error', 'Failed to parse review-approval JSON', { message: err.message });
      content = {};
    }

    if (content.status !== 'approved') {
      return false;
    }

    if (content.plan_hash !== expectedPlanHash) {
      return false;
    }
    if (content.diff_hash !== expectedDiffHash) {
      return false;
    }

    return true;
  } catch (err) {
    logGating('error', 'verifyReviewGate failed', { message: err.message });
    return false;
  }
}

export async function verifyCommitGate(targetDir, expectedDiffHash) {
  const userApprovalFile = path.join(targetDir, 'user-approval.json');
  const sigFile = path.join(targetDir, 'user-approval.json.sig');
  const pubKeyFile = path.resolve(os.homedir(), '.gemini/ssh-key.pub');

  const approvalData = await readFileSafe(userApprovalFile);
  const pubKeyContent = await readFileSafe(pubKeyFile);
  if (!approvalData || !fs.existsSync(sigFile) || !pubKeyContent) {
    return false;
  }

  try {
    const allowedSignersFile = path.join(targetDir, 'allowed_signers');
    await writeFileSafe(allowedSignersFile, `gemini ${pubKeyContent.trim()}`);

    const fileBuffer = await fsPromises.readFile(userApprovalFile);

    await execFileWithInput(
      'ssh-keygen',
      ['-Y', 'verify', '-f', allowedSignersFile, '-I', 'gemini', '-n', 'gemini', '-s', sigFile],
      {
        stdio: ['pipe', 'ignore', 'ignore'],
      },
      fileBuffer,
    );

    let content;
    try {
      content = JSON.parse(approvalData);
    } catch (err) {
      logGating('error', 'Failed to parse user-approval JSON', { message: err.message });
      content = {};
    }

    if (content.status !== 'approved') {
      return false;
    }

    if (content.diff_hash !== expectedDiffHash) {
      return false;
    }

    return true;
  } catch (err) {
    logGating('error', 'verifyCommitGate failed', { message: err.message });
    return false;
  }
}

export async function checkAndRevokeStaleGates(targetDir, activeDiffHash) {
  const reviewApprovalFile = path.join(targetDir, 'review-approval.json');
  let hasRevoked = false;

  const reviewData = await readFileSafe(reviewApprovalFile);
  if (reviewData !== null) {
    try {
      let content;
      try {
        content = JSON.parse(reviewData);
      } catch (err) {
        logGating('error', 'Failed to parse review-approval JSON', { message: err.message });
        content = {};
      }
      if (!content.diff_hash || (activeDiffHash && content.diff_hash !== activeDiffHash)) {
        await healApprovalState(targetDir, 'review');
        logGating(
          'error',
          'Active Gate Revocation: Stale review signature deleted because workspace changes were modified since your last review!',
        );
        hasRevoked = true;
      }
    } catch (err) {
      logGating('warn', `Failed to process review approval: ${err.message}`);
      await healApprovalState(targetDir, 'review');
      hasRevoked = true;
    }
  }

  const state = await readState(targetDir);
  if (state) {
    if (activeDiffHash && state.tested_diff_hash !== activeDiffHash) {
      await updateState(targetDir, { tested_diff_hash: '', tested_plan_hash: '' });
    }
  }

  return hasRevoked;
}

export async function revokeAllSignatures(targetDir) {
  console.log('::error::Zero-Trust Security Reset: Revoking all approvals and gating signatures...');
  const signatureFileNames = [
    'user-approval.json',
    'user-approval.json.sig',
    'review-approval.json',
    'plan-approval.json',
    'plan-approval.json.sig',
    'require-ask-user.flag',
  ];

  for (const name of signatureFileNames) {
    const file = path.join(targetDir, name);
    if (await deleteFileSafe(file)) {
      console.log(`::notice::Revoked signature file: ${name}`);
    }
  }
}

export async function revokeSignature(targetDir, fileName) {
  await deleteFileSafe(path.join(targetDir, fileName));
  await deleteFileSafe(path.join(targetDir, `${fileName}.sig`));
  if (fileName === 'user-approval.json' || fileName === 'review-approval.json') {
    await deleteFileSafe(path.join(targetDir, 'require-ask-user.flag'));
  }
}

export async function readApprovalData(targetDir, approvalFileName, key = null) {
  const approvalFile = path.join(targetDir, approvalFileName);
  const dataRaw = await readFileSafe(approvalFile);
  if (dataRaw) {
    try {
      const approvalData = JSON.parse(dataRaw);
      return key ? approvalData[key] : approvalData;
    } catch (err) {
      logGating('warn', `Failed to read from ${approvalFileName}: ${err.message}`);
    }
  }
  return null;
}

export async function extractCommitMessage(targetDir, promptText) {
  let commitMessage = (await readApprovalData(targetDir, 'review-approval.json', 'suggested_commit_message')) || '';

  if (!commitMessage) {
    const matchCommit =
      promptText.match(/(?:Commit|Proposed) Message:\s*(["'`])(.*?)\1/i) ||
      promptText.match(/(?:Commit|Proposed) Message:\s*(.*)/i);

    if (matchCommit) {
      commitMessage = (matchCommit[2] !== void 0 ? matchCommit[2] : matchCommit[1]).trim();
    } else if (promptText && promptText.trim() !== '') {
      commitMessage = promptText.trim();
    } else {
      commitMessage = 'chore: automated development commit';
    }
  }
  return commitMessage;
}

export async function verifyProactiveReview(cwd = process.cwd()) {
  let repoName;
  try {
    repoName = path.basename(await gitRevParseShowToplevel(cwd));
  } catch {
    repoName = path.basename(cwd);
  }

  const home = os.homedir() || '/tmp';
  let targetDir = process.env.AGENT_STATE_DIR || path.join(home, '.gemini/tmp', repoName);

  if (!fs.existsSync(path.join(targetDir, 'review-approval.json'))) {
    const parentDir = path.join(home, '.gemini/tmp', repoName);
    if (fs.existsSync(path.join(parentDir, 'review-approval.json'))) {
      targetDir = parentDir;
    }
  }

  console.error('Verifying proactive review approval status...');

  const currentBranch = await gitBranchShowCurrent(cwd);
  const activeDiff =
    currentBranch && currentBranch !== 'main' ? await gitDiff('main', cwd) : await gitDiff('HEAD', cwd);
  const activeHash = crypto.createHash('sha256').update(activeDiff).digest('hex');

  const reviewData = await readApprovalData(targetDir, 'review-approval.json');
  if (!reviewData) {
    console.error('Error: Proactive review approval file not found or could not be parsed!');
    console.error("       In accordance with Gate 3 (Review Gate) of 'docs/development/how-to/DevelopmentProcess.md',");
    console.error('       you MUST run the review script first: node agent-scripts/code-review.js');
    process.exit(1);
  }

  const status = reviewData.status || '';
  const diffHash = reviewData.diff_hash || '';

  if (status !== 'approved') {
    console.error(`Error: Proactive review approval status is '${status}' (not approved).`);
    process.exit(1);
  }

  if (diffHash !== activeHash) {
    console.error('Error: Local changes have been modified since your last proactive review!');
    console.error(`       Approved SHA-256 hash: ${diffHash}`);
    console.error(`       Current active SHA-256 hash: ${activeHash}`);
    console.error('       Please run the review agent again on your latest changes.');
    process.exit(1);
  }

  console.error(`✅ Proactive review approval verified! (SHA-256 Hash: ${activeHash})`);
}

// ==============================================================================
// MAIN HANDLERS
// ==============================================================================

/**
 * Handles the Planning Gate 1 biometric GPG signing challenge and output.
 */
export async function handlePlanApproval(targetDir, signingKeyFile, promptText) {
  const planContent = extractPlanContent(promptText);
  const activePlan = await savePlanContent(targetDir, planContent);

  if (!activePlan) {
    console.log('::error::Cryptographic Pipeline Error: Active plan file not found.');
    process.exit(1);
  }
  const planHash = await calculateFileHash(activePlan);
  if (!planHash) {
    console.log('::error::Cryptographic Pipeline Error: Failed to calculate active plan hash.');
    process.exit(1);
  }

  const envelope = {
    status: 'approved',
    plan_file: activePlan,
    plan_hash: planHash,
    timestamp: new Date().toISOString(),
  };

  try {
    await generateAndSignApproval(targetDir, 'plan-approval.json', signingKeyFile, envelope);
    return {
      status: 'approved',
      systemMessage: '✅ Gate 1 Approved: Plan cryptographically signed!',
    };
  } catch (err) {
    console.log(`::error::Cryptographic Pipeline Error: Failed to execute plan decryption: ${err.message || err}`);
    process.exit(1);
  }
}

/**
 * Handles the Review Gate 2 programmatic GPG/SSH signing challenge.
 */
export async function handleReviewApproval(targetDir, signingKeyFile) {
  const activePlan = await findLatestActivePlan(targetDir);
  const planHash = activePlan ? await calculateFileHash(activePlan) : 'unknown';
  const diffHash = await calculateDiffHash();

  if (!diffHash) {
    console.log('::error::Cryptographic Pipeline Error: Failed to calculate active diff hash.');
    process.exit(1);
  }

  const envelope = {
    status: 'approved',
    diff_hash: diffHash,
    plan_hash: planHash,
    timestamp: new Date().toISOString(),
  };

  try {
    await generateAndSignApproval(targetDir, 'review-approval.json', signingKeyFile, envelope);
    console.log('✅ Gate 2 Approved: Programmatic Review cryptographically signed!');
    return {
      status: 'approved',
      systemMessage: '✅ Gate 2 Approved: Programmatic Review cryptographically signed!',
    };
  } catch (err) {
    console.log(`::error::Cryptographic Pipeline Error: Failed to execute review signature: ${err.message || err}`);
    process.exit(1);
  }
}

/**
 * Handles the Commit Gate 3 GPG/SSH signing challenge and automatic commit/push.
 */
export async function handleCommitApproval(targetDir, signingKeyFile, promptText) {
  const activePlan = await findLatestActivePlan(targetDir);
  const planHash = activePlan ? await calculateFileHash(activePlan) : 'unknown';
  const diffHash = await calculateDiffHash();

  if (!diffHash) {
    console.log('::error::Cryptographic Pipeline Error: Failed to calculate active diff hash.');
    process.exit(1);
  }

  const envelope = {
    status: 'approved',
    diff_hash: diffHash,
    plan_hash: planHash,
    timestamp: new Date().toISOString(),
  };

  try {
    await generateAndSignApproval(targetDir, 'user-approval.json', signingKeyFile, envelope);

    const commitMessage = await extractCommitMessage(targetDir, promptText);
    const prUrl = await runAutomatedCommitAndPush(targetDir, commitMessage);
    return {
      status: 'approved',
      prUrl,
      systemMessage: `✅ Gate 3 Approved: Developer Commit cryptographically signed!\n🎉 PR successfully created: ${prUrl}`,
    };
  } catch (err) {
    console.log(
      `::error::Cryptographic Pipeline Error: Failed to execute Secure Enclave commit decryption: ${err.message || err}`,
    );
    process.exit(1);
  }
}

/**
 * Unified entry point
 */
export async function handleApproval(type, targetDir, signingKeyFile, promptText = '') {
  switch (type) {
    case 'plan':
      return await handlePlanApproval(targetDir, signingKeyFile, promptText);
    case 'review':
      return await handleReviewApproval(targetDir, signingKeyFile);
    case 'commit':
      return await handleCommitApproval(targetDir, signingKeyFile, promptText);
    default:
      console.log(`::error::Unknown approval type: ${type}`);
      process.exit(1);
  }
}

/**
 * Centralized self-healing routine to purge invalid gate files from the workspace.
 * Relocated to approval.js for SOLID SRP compliance.
 * @param {string} targetDir
 * @param {'plan'|'review'|'commit'|'all'} gateType
 */
export async function healApprovalState(targetDir, gateType = 'all') {
  console.log(`::notice::Self-Healing: Purging invalid or failed approval files for gate: ${gateType}`);

  if (gateType === 'plan' || gateType === 'all') {
    await deleteFileSafe(path.join(targetDir, 'plan-approval.json'));
    await deleteFileSafe(path.join(targetDir, 'plan-approval.json.sig'));
  }
  if (gateType === 'review' || gateType === 'all') {
    await deleteFileSafe(path.join(targetDir, 'review-approval.json'));
  }
  if (gateType === 'commit' || gateType === 'all') {
    await deleteFileSafe(path.join(targetDir, 'user-approval.json'));
    await deleteFileSafe(path.join(targetDir, 'user-approval.json.sig'));
    await deleteFileSafe(path.join(targetDir, 'require-ask-user.flag'));
  }
}
