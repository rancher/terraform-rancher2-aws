import os from 'os';
import path from 'path';
import { writeFileSafe } from '../../../agent-scripts/tools/file.js';
import { calculateDiffHash } from '../../../agent-scripts/tools/git.js';
import { readState, setLock } from '../../../agent-scripts/tools/state.js';
import {
  checkAndRevokeStaleGates,
  handleCommitApproval,
  readApprovalData,
  revokeSignature,
  verifyPlanGate,
  verifyReviewGate,
} from '../../../agent-scripts/tools/approval.js';
import {
  allow,
  deny,
  getPhase,
  getTomlFrom,
  hasValidSigningKey,
  parseToolResponse,
  validateAskUser,
} from '../shared.js';

async function inPlanMode(targetDir) {
  const phaseResult = await getPhase(targetDir);
  return phaseResult && phaseResult.success && phaseResult.data === 'plan';
}

export async function revokeReviewState(targetDir) {
  await revokeSignature(targetDir, 'review-approval.json');
  console.error('❌ Gate 2 (Review) Revoked: User rejected the commit. Review approval has been deleted.');
}

export async function preCommitPhaseInterruption(inputData, targetDir) {
  const state = (await readState(targetDir)) || {};
  const locked = state.locked || false;
  const keyTool = state.keyTool || '';

  if (locked && keyTool === 'ask_user') {
    if (inputData.tool_name !== 'ask_user') {
      deny(
        'Gate 3 (Commit Gate) Intercept',
        'The review phase has completed successfully. All tools are strictly blocked until you present the changes to the user for commit approval.',
        'Please call the `ask_user` tool to request commit approval and proceed.',
      );
    }

    // Present the suggested commit message from the review agent
    let suggestedCommitMessage = 'chore: automated development commit';
    const reviewMsg = await readApprovalData(targetDir, 'review-approval.json', 'suggested_commit_message');
    if (reviewMsg) {
      suggestedCommitMessage = reviewMsg;
    }

    const modifiedInput = inputData.tool_input || {};
    const reviewContext = `\n\n# ### 🔍 AUTOMATED REVIEW COMPLETE 🔍 ###\n# The review agent has verified the changes and formulated the following commit message:\n# \n# Commit Message: \`${suggestedCommitMessage}\`\n# \n# Please review the code changes in your IDE. Do you approve these changes for commit? (Yes/No)`;

    // Strip any raw "Commit Message:" directives the main agent might have formulated to avoid collision/parse issues
    const replaceCommitMsg = (str) =>
      typeof str === 'string' ? str.replace(/Commit Message/gi, 'Proposed Message') : str;

    if (modifiedInput.questions && Array.isArray(modifiedInput.questions) && modifiedInput.questions.length > 0) {
      modifiedInput.questions[0].question = replaceCommitMsg(modifiedInput.questions[0].question) + reviewContext;
    } else if (modifiedInput.question !== void 0) {
      modifiedInput.question = replaceCommitMsg(modifiedInput.question) + reviewContext;
    } else if (modifiedInput.prompt !== void 0) {
      modifiedInput.prompt = replaceCommitMsg(modifiedInput.prompt) + reviewContext;
    } else {
      modifiedInput.question = reviewContext;
    }

    console.log(
      JSON.stringify({
        decision: 'allow',
        tool_input: modifiedInput,
        systemMessage: '🟢 Pre-Commit Phase: Appended review agent commit message to the user prompt.',
      }),
    );
    process.exit(0);
  }
}

export async function beforeAskUserCommit(inputData, targetDir) {
  const { tool_name, tool_input } = inputData;
  const hookName = 'beforeAskUserCommit';

  if (tool_name !== 'ask_user' || !tool_input) {
    allow(hookName, tool_name);
  }

  if (await inPlanMode(targetDir)) {
    allow(hookName, tool_name);
  }

  // Run central TOML validation
  validateAskUser(hookName, tool_name, tool_input);

  const tomlData = getTomlFrom(tool_input);

  const commitIntent = tomlData.intent.trim().toLowerCase();
  const isCommitAsk = commitIntent === 'commit approval';

  const hasCommitFields =
    Object.prototype.hasOwnProperty.call(tomlData, 'hash') ||
    Object.prototype.hasOwnProperty.call(tomlData, 'commit-message') ||
    Object.prototype.hasOwnProperty.call(tomlData, 'pr-description');
  if (hasCommitFields && !isCommitAsk) {
    deny(
      'Gate 3 (Commit Gate) Intent Validation',
      `The TOML payload contains commit-specific fields, but the intent is set to "${tomlData.intent}".`,
      'To request commit approval, you must set intent = "commit approval" in your TOML payload.',
    );
  }

  if (!isCommitAsk) {
    allow(hookName, tool_name);
  }

  // Validate specific fields
  if (!tomlData.hash || typeof tomlData.hash !== 'string') {
    deny(
      'Gate 3 (Commit Gate) Schema Validation',
      "For commit approval intent, the string 'hash' field containing the review phase diff hash is required.",
      "Include the 'hash' field in your TOML with the exact diff SHA-256 hash calculated from the review phase.",
    );
  }
  if (!tomlData['commit-message'] || typeof tomlData['commit-message'] !== 'string') {
    deny(
      'Gate 3 (Commit Gate) Schema Validation',
      "For commit approval intent, the string 'commit-message' field containing the approved commit message is required.",
      "Include the 'commit-message' field in your TOML with the exact conventional commit message to use for the automated commit.",
    );
  }
  if (!tomlData['pr-description'] || typeof tomlData['pr-description'] !== 'string') {
    deny(
      'Gate 3 (Commit Gate) Schema Validation',
      "For commit approval intent, the string 'pr-description' field containing the pull request description is required.",
      "Include the 'pr-description' field in your TOML with the detailed description/body to use when programmatically opening the Pull Request.",
    );
  }

  const planHash = await verifyPlanGate(targetDir);
  if (!planHash) {
    deny(
      'Gate 3 (Commit Gate) Pipeline Verification',
      'You cannot ask for Developer Commit Approval (Gate 3) because Gate 1 (Planning Gate) is missing or invalid!',
      'Please obtain planning approval from the developer first by writing plans/ and calling ask_user with intent = "plan approval".',
    );
  }

  const diffHash = await calculateDiffHash();

  await checkAndRevokeStaleGates(targetDir, diffHash, planHash);

  const reviewPassed = await verifyReviewGate(targetDir, diffHash, planHash);
  if (!reviewPassed) {
    deny(
      'Gate 3 (Commit Gate) Quality Verification',
      'You cannot ask for Developer Commit Approval (Gate 3) because the Review prerequisite (Gate 2) is missing or has been invalidated by recent file changes!',
      'Please run the review script first to perform a code review and sign the branch: node agent-scripts/code-review.js',
    );
  }

  allow(hookName, tool_name);
}

export async function afterAskUserCommit(inputData, targetDir) {
  const { tool_name, tool_input, tool_response } = inputData;
  const hookName = 'afterAskUserCommit';

  if (tool_name !== 'ask_user' || !tool_input || !tool_response) {
    allow(hookName, tool_name);
  }

  if (await inPlanMode(targetDir)) {
    allow(hookName, tool_name);
  }

  const state = await readState(targetDir);
  if (state && state.locked && state.keyTool === 'ask_user') {
    await setLock(targetDir, false);
  }

  validateAskUser(hookName, tool_name, tool_input);
  const tomlData = getTomlFrom(tool_input);

  const commitIntent = tomlData && tomlData.intent ? tomlData.intent.trim().toLowerCase() : '';
  const isCommitAsk = commitIntent === 'commit approval';

  if (!isCommitAsk) {
    allow(hookName, tool_name);
  }

  // Use the robust response parser from shared.js
  const answerText = parseToolResponse(tool_response);

  const isApproved =
    String(answerText || '')
      .trim()
      .toLowerCase() === 'yes';

  if (!isApproved) {
    if (isCommitAsk) {
      console.error(
        '🔒 Hook Info: Commit approval declined, but Gate 2 (Review) remains intact as the workspace was not modified.',
      );
    }
    allow(hookName, tool_name);
  }

  if (tomlData && commitIntent === 'commit approval') {
    const commitMsg = tomlData['commit-message'];
    const prDesc = tomlData['pr-description'];

    if (commitMsg) {
      const approvalData = await readApprovalData(targetDir, 'review-approval.json');
      if (approvalData) {
        try {
          approvalData.suggested_commit_message = commitMsg;
          await revokeSignature(targetDir, 'review-approval.json'); // Ensures fresh rewrite over restrictive perms
          const reviewApprovalFile = path.join(targetDir, 'review-approval.json');
          await writeFileSafe(reviewApprovalFile, JSON.stringify(approvalData, null, 2), { mode: 0o400 });
          console.error(`🔒 Hook Info: Updated suggested_commit_message in review-approval.json to: "${commitMsg}"`);
        } catch (err) {
          console.error('🔒 Hook Error: Failed to update review-approval.json with commit-message:', err.message);
        }
      }
    }

    if (prDesc) {
      const prBodyFile = path.join(targetDir, 'pr-body.md');
      try {
        await writeFileSafe(prBodyFile, prDesc);
        console.error(`🔒 Hook Info: Wrote PR description to ${prBodyFile}`);
      } catch (err) {
        console.error('🔒 Hook Error: Failed to write pr-body.md:', err.message);
      }
    }
  }

  if (isCommitAsk) {
    if (!hasValidSigningKey()) {
      deny(
        'Gate 3 (Commit Gate) Cryptographic Setup',
        'SSH key signing is not configured properly or your SSH agent is offline.',
        'To resolve this, please perform the following setup steps:\n' +
          '1. Ensure your SSH agent is running: eval "$(ssh-agent -s)"\n' +
          '2. Generate an SSH key if you do not have one under ~/.gemini/:\n' +
          '   ssh-keygen -t ed25519 -f ~/.gemini/ssh-key -C "gemini-signing-key"\n' +
          '3. Add your SSH key to the active ssh-agent:\n' +
          '   ssh-add ~/.gemini/ssh-key\n' +
          '4. Ensure your public key exists and is readable at ~/.gemini/ssh-key.pub.\n\n' +
          'Once configured, re-run the `ask_user` tool with intent = "commit approval".',
      );
    }

    const planHash = await verifyPlanGate(targetDir);
    const diffHash = await calculateDiffHash();
    await checkAndRevokeStaleGates(targetDir, diffHash, planHash);

    const reviewPassed = await verifyReviewGate(targetDir, diffHash, planHash);
    if (!reviewPassed) {
      allow(hookName, tool_name);
    }

    const homeDir = os.homedir();
    const sshPubKeyFile = path.resolve(homeDir, '.gemini/ssh-key.pub');
    const promptText = tomlData['commit-message'] || '';
    const result = await handleCommitApproval(targetDir, sshPubKeyFile, promptText);
    allow(hookName, tool_name, tool_input, '', '\n\n' + (result ? result.systemMessage : ''));
  }

  allow(hookName, tool_name);
}
