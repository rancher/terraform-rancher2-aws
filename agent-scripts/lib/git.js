import { execFile } from 'child_process';
import crypto from 'crypto';
import fs, { promises as fsPromises } from 'fs';
import path from 'path';
import process from 'process';
import { promisify } from 'util';
import { executeFileSafe, writeFileSafe } from './file.js';
import { view as prView } from './pr.js';

const execFileAsync = promisify(execFile);

const COMMIT_PUSH_SCRIPT = process.env.COMMIT_PUSH_SCRIPT_PATH || 'agent-scripts/tools/git.js';

/**
 * Executes a git command safely using execFile to prevent shell injection.
 * @param {string[]} args - The arguments to pass to git.
 * @param {string} cwd - The current working directory.
 * @returns {Promise<string>} - The trimmed standard output of the command.
 */
export async function executeGit(args, cwd = process.cwd()) {
  try {
    const { stdout } = await execFileAsync('git', args, {
      cwd: cwd || process.cwd(),
      stdio: ['ignore', 'pipe', 'pipe'],
      encoding: 'utf-8',
    });
    return sanitizeOutput(stdout.trim());
  } catch (err) {
    const safeMsg = sanitizeOutput(err.message || '');
    const safeStderr = err.stderr ? sanitizeOutput(err.stderr.trim()) : '';
    const safeArgs = args.map((arg) => sanitizeOutput(arg));
    const fullError = safeStderr ? `${safeMsg}\nStderr: ${safeStderr}` : safeMsg;
    throw new Error(`Git command failed: git ${safeArgs.join(' ')}. Error: ${fullError}`, { cause: err });
  }
}

export async function gitBranchShowCurrent(cwd) {
  return await executeGit(['branch', '--show-current'], cwd);
}
export async function gitRevParseShowToplevel(cwd) {
  return await executeGit(['rev-parse', '--show-toplevel'], cwd);
}
export async function gitRevParseGitDir(cwd) {
  return await executeGit(['rev-parse', '--git-dir'], cwd);
}
export async function gitRemoteGetUrl(remoteName, cwd) {
  return await executeGit(['remote', 'get-url', remoteName], cwd);
}
export async function gitRemoteVerbose(cwd) {
  return await executeGit(['remote', '-v'], cwd);
}
export async function gitRevParseHead(cwd) {
  return await executeGit(['rev-parse', 'HEAD'], cwd);
}
export async function gitRevParseBranch(remoteName, branch, cwd) {
  return await executeGit(['rev-parse', `${remoteName}/${branch}`], cwd);
}
export async function gitMergeBaseIsAncestor(ancestor, descendant, cwd) {
  return await executeGit(['merge-base', '--is-ancestor', ancestor, descendant], cwd);
}
export async function gitFetchQuiet(remoteName, branch, cwd) {
  return await executeGit(['fetch', '-q', remoteName, branch], cwd);
}
export async function gitAddAll(cwd) {
  return await executeGit(['add', '-A'], cwd);
}
export async function gitStatusPorcelain(cwd) {
  return await executeGit(['status', '--porcelain'], cwd);
}
export async function gitSwitch(branch, cwd) {
  return await executeGit(['switch', branch], cwd);
}
export async function gitCheckout(branch, cwd) {
  return await executeGit(['checkout', branch], cwd);
}
export async function gitCheckoutNewBranch(branch, cwd) {
  return await executeGit(['checkout', '-b', branch], cwd);
}
export async function gitBranchList(cwd) {
  return await executeGit(['branch', '--list', '--format=%(refname:short)'], cwd);
}
export async function gitLogLastSubject(cwd) {
  return await executeGit(['log', '-1', '--pretty=%s'], cwd);
}
export async function gitLogLastBody(cwd) {
  return await executeGit(['log', '-1', '--pretty=%b'], cwd);
}
export async function gitDiffCachedNameOnly(cwd) {
  return await executeGit(['diff', '--cached', '--name-only'], cwd);
}
export async function gitDiffCachedQuiet(cwd) {
  return await executeGit(['diff', '--cached', '--quiet'], cwd);
}
export async function gitLsFilesOthersExcludeStandard(cwd) {
  return await executeGit(['ls-files', '--others', '--exclude-standard'], cwd);
}
export async function gitDiff(target, cwd) {
  return await executeGit(target ? ['diff', target] : ['diff'], cwd);
}
export async function gitDiffStaged(cwd) {
  return await executeGit(['diff', '--staged'], cwd);
}
export async function gitDiffStagedContext(cwd) {
  return await executeGit(['diff', '-U10', 'HEAD', '--staged'], cwd);
}
export async function gitDiffHeadNameOnly(cwd) {
  return await executeGit(['diff', 'HEAD', '--name-only'], cwd);
}
export async function gitDiffFileContext(file, cwd) {
  return await executeGit(['diff', '-U10', 'HEAD', '--', file], cwd);
}
export async function gitStashList(cwd) {
  return await executeGit(['stash', 'list'], cwd);
}
export async function gitStashPush(message, cwd) {
  return await executeGit(['stash', 'push', '-u', '-m', message], cwd);
}
export async function gitStashPop(stashRef, cwd) {
  return await executeGit(['stash', 'pop', '--index', stashRef], cwd);
}
export async function gitRevParseVerify(ref, cwd) {
  return await executeGit(['rev-parse', '--verify', ref], cwd);
}
export async function gitCloneDepth1(repoUrl, targetDir, cwd = process.cwd()) {
  return await executeGit(['clone', '--depth', '1', repoUrl, targetDir], cwd);
}
export async function gitCloneDepth1NoCheckout(repoUrl, targetDir, cwd = process.cwd()) {
  return await executeGit(['clone', '--depth', '1', '--no-checkout', repoUrl, targetDir], cwd);
}
export async function gitCheckoutPath(pathspec, cwd = process.cwd()) {
  return await executeGit(['checkout', 'HEAD', '--', pathspec], cwd);
}

export async function verifyPushSafety(remoteName, cwd = process.cwd()) {
  let url = '';
  try {
    url = await gitRemoteGetUrl(remoteName, cwd);
  } catch {
    // Ignore, remote might not exist
  }

  if (!url) {
    console.error(`Error: Remote '${remoteName}' has no configured URL.`);
    process.exit(1);
  }

  if (/[/:]rancher(labs)?\//i.test(url)) {
    console.error('======================================================================');
    console.error('❌ CRITICAL SECURITY ERROR: UNSAFE PUSH PREVENTED!');
    console.error(`   The remote '${remoteName}' points to a Rancher-owned repository:`);
    console.error(`   ${url}`);
    console.error('   Pushing directly to upstream Rancher repositories is strictly forbidden.');
    console.error('======================================================================');
    process.exit(1);
  }
}

export async function checkDefunctBranch(branch, cwd = process.cwd()) {
  if (branch === 'main') {
    return;
  }
  try {
    const prInfo = await prView(branch, ['state', 'number'], cwd);
    if (prInfo && prInfo.state === 'MERGED') {
      console.error(
        `Error: The current branch '${branch}' already has a merged Pull Request (#${prInfo.number}) on GitHub.`,
      );
      console.error(
        `       This branch is defunct. In accordance with 'docs/development/how-to/DevelopmentProcess.md' Phase 5, Step 12, you MUST:`,
      );
      console.error(`       1. Switch to 'main': git checkout main`);
      console.error(`       2. Synchronize with upstream default branch: bash agent-scripts/git-sync.sh`);
      console.error(
        `       3. Check out a clean, new branch off updated main: git checkout -b feature/workflows-new-branch`,
      );
      process.exit(1);
    }
  } catch {
    // Ignored, PR likely does not exist
  }
}

export async function popStashByMessage(stashMsg, cwd = process.cwd()) {
  try {
    const stashList = await gitStashList(cwd);
    const match = stashList.split('\n').find((line) => line.includes(stashMsg));
    if (match) {
      const stashRef = match.split(':')[0];
      await gitStashPop(stashRef, cwd);
    }
  } catch {
    console.error('Warning: Re-applying stashed changes resulted in merge conflicts.');
    console.error('         Your stashed changes have been PRESERVED in the Git stash list.');
  }
}

export async function syncDefaultBranch(branch, cwd = process.cwd()) {
  if (branch !== 'main') {
    const gitDir = await gitRevParseGitDir(cwd);
    if (
      fs.existsSync(path.join(gitDir, 'MERGE_HEAD')) ||
      fs.existsSync(path.join(gitDir, 'CHERRY_PICK_HEAD')) ||
      fs.existsSync(path.join(gitDir, 'REBASE_HEAD'))
    ) {
      console.error(
        '--> [MERGE STATE] Active merge/rebase/cherry-pick in progress. Skipping sync_default_branch to preserve merge state.',
      );
      return;
    }
    console.error("Synchronizing local 'main' branch and tags with upstream parent repository...");

    let stashCreated = false;
    const stashMsg = `temp-commit-push-stash-${process.pid}`;
    const hasChanges = (await gitStatusPorcelain(cwd)) !== '';

    if (hasChanges) {
      console.error('  -> Temporarily stashing unstaged/untracked files...');
      await gitStashPush(stashMsg, cwd);
      stashCreated = true;
    }

    try {
      await syncUpstreamDefaultBranch(cwd);
    } catch (err) {
      console.error(`Error: Upstream synchronization failed: ${err.message || err}`);
      if (stashCreated) {
        await popStashByMessage(stashMsg, cwd);
      }
      process.exit(1);
    }

    console.error(`Switching back to branch '${branch}'...`);
    try {
      await gitCheckout(branch, cwd);
    } catch {
      console.error(`Error: Failed to switch back to branch '${branch}' after sync.`);
      if (stashCreated) {
        await popStashByMessage(stashMsg, cwd);
      }
      process.exit(1);
    }

    if (stashCreated) {
      console.error('  -> Restoring stashed unstaged/untracked files...');
      await popStashByMessage(stashMsg, cwd);
    }
  }
}

export async function syncUpstreamDefaultBranch(cwd = process.cwd()) {
  const originUrl = await gitRemoteGetUrl('origin', cwd);
  await verifyPushSafety('origin', cwd);

  const originOwnerMatch = originUrl.match(/github\.com[:/]([^/]+)\//);
  const originOwner = originOwnerMatch ? originOwnerMatch[1] : '';
  const upstreamOwner = 'rancher';
  const repoMatch = originUrl.match(/github\.com[:/][^/]+\/([^/]+)(?:\.git)?/);
  const upstreamRepo = repoMatch ? repoMatch[1].replace('.git', '') : path.basename(await gitRevParseShowToplevel(cwd));

  if (originOwner === upstreamOwner) {
    console.log(`Origin is already the upstream repository (${upstreamOwner}), nothing to sync.`);
    return;
  }

  let defaultBranch = 'main';
  try {
    const symRef = await executeGit(['symbolic-ref', 'refs/remotes/origin/HEAD'], cwd);
    defaultBranch = symRef.replace('refs/remotes/origin/', '').trim();
  } catch {
    const show = await executeGit(['remote', 'show', 'origin'], cwd);
    const match = show.match(/HEAD branch: (.*)/);
    if (match) {
      defaultBranch = match[1].trim();
    }
  }

  const upstreamUrl = originUrl.startsWith('git@')
    ? `git@github.com:${upstreamOwner}/${upstreamRepo}.git`
    : `https://github.com/${upstreamOwner}/${upstreamRepo}.git`;

  try {
    await executeGit(['remote', 'rm', 'upstream'], cwd);
  } catch {
    /* ignore */
  }
  await executeGit(['remote', 'add', 'upstream', upstreamUrl], cwd);
  await executeGit(['fetch', '--all'], cwd);

  const originalBranch = await gitBranchShowCurrent(cwd);
  await executeGit(['checkout', defaultBranch], cwd);
  await executeGit(['pull', '--rebase', 'upstream', defaultBranch], cwd);

  try {
    await execFileAsync('git', ['push', '--tags', 'origin'], { cwd, stdio: 'inherit' });
    await execFileAsync('git', ['push', '-f', 'origin', defaultBranch], { cwd, stdio: 'inherit' });
  } catch (err) {
    throw new Error(`Failed to push synced branch to origin: ${err.message}`, { cause: err });
  } finally {
    try {
      await executeGit(['remote', 'rm', 'upstream'], cwd);
    } catch {
      /* ignore */
    }
    if (originalBranch !== defaultBranch) {
      await executeGit(['checkout', originalBranch], cwd);
    }
  }
}

// Calculate active local diff hash securely (staged + unstaged combined, relative to main on feature branches, and including untracked files)
export async function calculateDiffHash(cwd = process.cwd()) {
  try {
    const currentBranch = await gitBranchShowCurrent(cwd);

    const hash = crypto.createHash('sha256');

    // 1. Accumulate tracked diffs
    if (currentBranch !== 'main' && currentBranch !== '') {
      // Feature branch: diff working tree (staged + unstaged) against main
      const diffMain = await gitDiff('main', cwd);
      hash.update(diffMain);
    } else {
      // Main or detached HEAD: diff unstaged changes
      const diffUnstaged = await gitDiff(null, cwd);
      hash.update(diffUnstaged);
      // Diff staged changes
      const diffStaged = await gitDiffStaged(cwd);
      hash.update(diffStaged);
    }

    // 2. Accumulate untracked files to prevent silent additions
    const untrackedFiles = (await gitLsFilesOthersExcludeStandard(cwd)).split('\n').filter(Boolean);

    for (const file of untrackedFiles) {
      const absolutePath = path.resolve(cwd, file);
      try {
        const stats = await fsPromises.stat(absolutePath);
        if (stats.isFile()) {
          const fileContent = await fsPromises.readFile(absolutePath);
          hash.update(`untracked:${file}\n`);
          hash.update(fileContent);
        }
      } catch (fileErr) {
        console.log(`::error::Failed to read untracked file ${file} {"message":"${fileErr.message}"}`);
      }
    }

    return hash.digest('hex');
  } catch (err) {
    console.log(`::error::calculateDiffHash failed {"message":"${err.message}"}`);
    return null;
  }
}

export async function runAutomatedCommitAndPush(targetDir, commitMessage, cwd = process.cwd()) {
  console.log(`::notice::🚀 AUTOMATION TRIGGERED: Initiating commit and push...`);
  const pushArgs = ['commit-push', '-m', commitMessage];

  let activeBranch = '';
  try {
    activeBranch = await gitBranchShowCurrent(cwd);
    let hasTracking = '';
    try {
      hasTracking = await gitRevParseVerify(`origin/${activeBranch}`, cwd);
    } catch (err) {
      console.log(
        `::warning::Hook Debug: Tracking reference does not exist yet for branch ${activeBranch}: ${err.message}`,
      );
    }

    if (hasTracking) {
      try {
        let isOriginAncestorOfHead = false;
        try {
          await gitMergeBaseIsAncestor(`origin/${activeBranch}`, 'HEAD', cwd);
          isOriginAncestorOfHead = true;
        } catch (err) {
          isOriginAncestorOfHead = false;
          console.log(`::warning::Hook Debug: Origin tracking is not ancestor of HEAD: ${err.message}`);
        }

        if (!isOriginAncestorOfHead) {
          console.log(
            '::warning::⚠️ [OUT-OF-SYNC] Local branch is out-of-sync with origin tracking ref. Please resolve manually or request approval for force-push.',
          );
        }
      } catch (err) {
        console.log(
          `::warning::Hook Debug: Rebase detection failed, falling back to standard push args: ${err.message}`,
        );
      }
    }
  } catch (err) {
    console.log(`::warning::Hook Debug: Git tracking check failed, falling back safely: ${err.message}`);
  }

  try {
    const commitScriptPath = path.resolve(cwd, COMMIT_PUSH_SCRIPT);
    console.log(`::notice::Hook Info: Spawning ${path.basename(COMMIT_PUSH_SCRIPT)} with args: ${pushArgs.join(' ')}`);
    const commitOut = await executeFileSafe(commitScriptPath, pushArgs, {
      env: { ...process.env, COMMIT_LIMIT_OVERRIDE: '100' },
      cwd,
      stdio: ['ignore', 'pipe', 'pipe'],
      maxBuffer: 10 * 1024 * 1024,
    });
    if (commitOut && commitOut.trim()) {
      console.log(`::notice::${commitOut.trim()}`);
    }

    const prScriptPath = path.resolve(cwd, 'agent-scripts/pr.js');
    console.log(`::notice::Hook Info: Spawning pr.js to create pull request for branch ${activeBranch}`);
    const prOut = await executeFileSafe(
      prScriptPath,
      ['create', `Feature: ${activeBranch}`, 'Automated PR created by Gemini.', 'main', activeBranch],
      {
        env: { ...process.env },
        cwd,
        stdio: ['ignore', 'pipe', 'pipe'],
        maxBuffer: 10 * 1024 * 1024,
      },
    );
    const prUrl = prOut ? prOut.trim() : '';
    if (prUrl) {
      console.log(`::notice::${prUrl}`);
    }
    return prUrl;
  } catch (err) {
    const errorLogFileName = 'commit-push-error.log';
    const errorLog = path.join(targetDir, 'logs', errorLogFileName);
    const stdErrText = err.stderr ? err.stderr.toString() : '';
    const stdOutText = err.stdout ? err.stdout.toString() : '';

    try {
      await writeFileSafe(
        errorLog,
        `Error: ${err.message}\n\n--- SCRIPT STDERR ---\n${stdErrText}\n\n--- SCRIPT STDOUT ---\n${stdOutText}\n`,
      );
    } catch (logErr) {
      console.log(`::warning::Hook Debug: Failed to write error log: ${logErr.message || logErr}`);
    }

    console.log('::error::AUTOMATED COMMIT/PUSH PIPELINE FAILURE DETECTED!');
    console.log(`::error::Error Message: ${err.message || err}`);
    console.log(`::error::Script Stderr: ${stdErrText.trim() || 'None'}`);
    console.log(`::error::Script Stdout: ${stdOutText.trim() || 'None'}`);
    console.log(`::error::Full details written to: ${errorLog}`);
    console.log('::error::Troubleshooting Guide:');
    console.error('::error::1. Check if your local branch has un-synchronized remote commits.');
    console.error('::error::2. Ensure your GPG keys are unlocked and Touch ID biometrics are functioning.');
    console.error('::error::3. Check GitHub API status and ensure your gh CLI is authenticated.');

    throw err;
  }
}

export async function executePush(remoteName, branch, forcePush, cwd = process.cwd()) {
  await verifyPushSafety(remoteName, cwd);

  const args = ['push', '-u', remoteName, branch];
  if (forcePush) {
    args.push('--force-with-lease');
    console.error(`Safely force-pushing branch '${branch}' to '${remoteName}' with lease...`);
  } else {
    console.error(`Pushing branch '${branch}' to '${remoteName}'...`);
  }

  try {
    // Intentionally inheriting stdio to allow prompts for auth or GPG pinentry
    await execFileAsync('git', args, { cwd: cwd || process.cwd(), stdio: 'inherit', encoding: 'utf-8' });
  } catch {
    console.error(`Error: Remote ${forcePush ? 'force-push with lease' : 'push'} failed.`);
    process.exit(1);
  }

  console.error(`✅ Changes successfully pushed to remote '${remoteName}/${branch}'!`);
}

export async function executeCommit(commitMsg, branch, cwd = process.cwd()) {
  console.error(`Creating conventional signed commit on branch '${branch}'...`);
  try {
    let signingKey;
    try {
      signingKey = await executeGit(['config', 'user.signingkey'], cwd);
    } catch {
      // Ignore config retrieve errors
    }

    const args = [];
    if (signingKey) {
      args.push('-c', `user.signingkey=${signingKey}`);
    }
    args.push('commit', '-S', '-s', '-m', commitMsg);

    await execFileAsync('git', args, {
      cwd: cwd || process.cwd(),
      stdio: 'inherit',
      encoding: 'utf-8',
    });
  } catch (err) {
    console.error(`Error: Commit failed: ${err.message}`);
    process.exit(1);
  }
}

export async function verifyStagingLimits(cwd = process.cwd()) {
  let maxAllowed = 5;
  if (process.env.COMMIT_LIMIT_OVERRIDE) {
    if (!/^[0-9]+$/.test(process.env.COMMIT_LIMIT_OVERRIDE)) {
      console.error(
        `Error: COMMIT_LIMIT_OVERRIDE must be a positive integer, got: '${process.env.COMMIT_LIMIT_OVERRIDE}'`,
      );
      process.exit(1);
    }
    maxAllowed = parseInt(process.env.COMMIT_LIMIT_OVERRIDE, 10);
    console.error(`--> [OVERRIDE] Using custom staged file limit from COMMIT_LIMIT_OVERRIDE: ${maxAllowed}`);
  }

  let stagedCountStr = '';
  try {
    stagedCountStr = await gitDiffCachedNameOnly(cwd);
  } catch {
    /* ignore */
  }

  const stagedCount = stagedCountStr ? stagedCountStr.split('\n').filter(Boolean).length : 0;

  if (stagedCount === 0) {
    let gitDir;
    try {
      gitDir = await gitRevParseGitDir(cwd);
    } catch {
      gitDir = '.git';
    }

    const absoluteGitDir = path.resolve(cwd, gitDir);
    if (
      fs.existsSync(path.join(absoluteGitDir, 'MERGE_HEAD')) ||
      fs.existsSync(path.join(absoluteGitDir, 'CHERRY_PICK_HEAD')) ||
      fs.existsSync(path.join(absoluteGitDir, 'REBASE_HEAD'))
    ) {
      console.error(
        '--> [MERGE STATE] Active merge/rebase/cherry-pick in progress. Allowing 0 staged files to create merge commit.',
      );
      return;
    }
    console.error('Error: No changes are currently staged for commit.');
    console.error("       Please stage your changes first using 'git add <files>...'.");
    process.exit(1);
  }

  if (stagedCount > maxAllowed) {
    console.error(
      `Error: Committing too much code at once is prohibited (${stagedCount} files staged; max allowed is ${maxAllowed}).`,
    );
    console.error(
      "       In accordance with Phase 5, Step 11 of 'docs/development/how-to/DevelopmentProcess.md', please split your commit into smaller, surgical layers.",
    );
    process.exit(1);
  }
}

export async function verifyRemoteAncestry(branch, cwd = process.cwd()) {
  const remoteName = 'origin';
  console.error('Verifying local branch ancestry is fully up-to-date with remote fork...');

  try {
    await gitFetchQuiet(remoteName, branch, cwd);
  } catch {
    console.error(
      `--> [FETCH SKIPPED] Tracking reference on remote '${remoteName}/${branch}' does not exist yet. Safe to proceed.`,
    );
    return;
  }

  let localSha = '';
  try {
    localSha = await gitRevParseHead(cwd);
  } catch {
    /* ignore */
  }

  let remoteSha = '';
  try {
    remoteSha = await gitRevParseBranch(remoteName, branch, cwd);
  } catch {
    /* ignore */
  }

  if (!remoteSha) {
    console.error('--> [RESOLVE SKIPPED] No remote tracking branch SHA found. Safe to proceed.');
    return;
  }

  if (localSha === remoteSha) {
    console.error('✅ Local branch is identical to remote fork tracking reference.');
    return;
  }

  try {
    await gitMergeBaseIsAncestor(remoteSha, localSha, cwd);
    console.error('✅ Local branch contains all remote tracking changes (Fast-Forward ancestry confirmed).');
    return;
  } catch {
    console.error('======================================================================');
    console.error('❌ CRITICAL FAILURE: LOCAL BRANCH IS OUT-OF-SYNC WITH REMOTE FORK!');
    console.error(`   Remote tracking reference '${remoteName}/${branch}' (${remoteSha}) has changes`);
    console.error('   that are not present in your local branch. Direct pushing is unsafe.');
    console.error('   To resolve, please execute our synchronized branch rebase:');
    console.error('   1. Stash any unstaged changes: git stash');
    console.error(`   2. Rebase HEAD onto remote tracking ref: git rebase ${remoteName}/${branch}`);
    console.error('   3. Restore stashed changes: git stash pop');
    console.error('======================================================================');
    process.exit(1);
  }
}

export async function verifySafeGitCommand(commandClean, cwd = process.cwd()) {
  // Check if we are attempting to switch branches while current PR is in Draft mode
  let isBranchSwitch = false;
  if (/\bgit\s+switch\b/.test(commandClean)) {
    isBranchSwitch = true;
  } else if (/\bgit\s+checkout\b/.test(commandClean)) {
    const hasDoubleDash = commandClean.includes(' -- ');
    if (hasDoubleDash) {
      isBranchSwitch = false;
    } else {
      const parts = commandClean.split(/\s+/).filter((p) => p !== 'git' && p !== 'checkout');
      const nonFlagParts = parts.filter((p) => !p.startsWith('-') || p === '-');

      if (nonFlagParts.length > 0) {
        const target = nonFlagParts[0];
        if (target === '-') {
          isBranchSwitch = true;
        } else {
          const resolvedTarget = path.resolve(cwd, target);
          if (!fs.existsSync(resolvedTarget)) {
            isBranchSwitch = true;
          }
        }
      } else {
        isBranchSwitch = false;
      }
    }
  }

  if (isBranchSwitch) {
    try {
      const currentBranch = await gitBranchShowCurrent(cwd);

      if (currentBranch && currentBranch !== 'main') {
        let prInfo = null;
        try {
          prInfo = await prView(currentBranch, ['isDraft', 'number'], cwd);
        } catch (err) {
          console.error('🔒 Hook Info: PR not found or API unreachable:', err.message || err);
        }

        if (prInfo && prInfo.isDraft === true) {
          return {
            decision: 'deny',
            reason: `Security Policy Violation: Moving to a new PR or branch is prohibited while the current branch PR (#${prInfo.number}) is still in Draft mode.\n\nIn accordance with Phase 6, Step 18 (Convert to Ready) and Phase 7, Step 20 (Proceed to Next Layer) of 'docs/development/how-to/DevelopmentProcess.md', you MUST first graduate the current PR from Draft to Ready-for-Review before checking out 'main' or switching tasks.\n\nTo proceed:\n1. Complete all iteration reviews and obtain local sign-off.\n2. Convert the draft PR to Ready-for-Review (Phase 6, Step 18) using: \`gh pr ready ${prInfo.number}\` (or the create-pr.sh skill).\n3. Once the PR is marked as ready for review on GitHub, you will be authorized to switch branches (Phase 7, Step 20).`,
            systemMessage: `🔒 Security Block: Current PR #${prInfo.number} is in Draft mode. Please comply with Phase 6, Step 18 of docs/development/how-to/DevelopmentProcess.md.`,
          };
        }
      }
    } catch (err) {
      return {
        decision: 'deny',
        reason: `Security Policy Violation: Failed to verify draft PR status on GitHub. To prevent branch state divergence, operations are blocked until status can be verified. Error: ${err.message || err}`,
        systemMessage: '🔒 Security Block: Branch PR verification failed.',
      };
    }
  }

  // Check for unauthorized git commit or push operations
  const isCommitOrPush = /\bgit\s+(commit|push)\b/.test(commandClean);
  if (isCommitOrPush) {
    return {
      decision: 'deny',
      reason: `Security Policy Violation: Direct manual git commit and push commands are strictly prohibited in this repository.\n\nIn accordance with Phase 6, Step 15 (Authorized Commit & Push) of 'docs/development/how-to/DevelopmentProcess.md', only our secure automated commit hooks are authorized to execute commits and pushes upon verified Touch ID signing.\n\nTo proceed:\n1. Stage your changes cleanly: \`git add <files>...\`\n2. Request developer commit approval by calling the \`ask_user\` tool with \`intent = "commit approval"\` containing your TOML payload.\n3. Upon developer approval, our secure automated commit hooks will automatically sign, commit, and push the changes for you.`,
      systemMessage:
        '🔒 Security Block: Direct git commit/push is blocked. Please stage files and call the ask_user tool with intent = "commit approval" to proceed.',
    };
  }

  // Check if it is a git command and performs a remote-interacting operation
  const isGitCmd = /^(?:sudo\s+)?git\b/.test(commandClean);
  const isRemoteOp = /\b(push|pull|fetch|clone|remote)\b/.test(commandClean);

  if (isGitCmd && isRemoteOp) {
    const hasRancherRef = /rancher/i.test(commandClean);
    if (hasRancherRef) {
      return {
        decision: 'deny',
        reason:
          'Security Policy Violation: Git command contains references to Rancher remote/URLs, which is strictly blocked.',
        systemMessage: '🔒 Security Block: Prohibited remote/URL reference detected.',
      };
    }

    try {
      const remotesOutput = await gitRemoteVerbose(cwd);

      if (/rancher/i.test(remotesOutput)) {
        return {
          decision: 'deny',
          reason:
            'Security Policy Violation: Operations (push, pull, fetch, remote) targeting Rancher-owned remotes are strictly blocked.',
          systemMessage: '🔒 Security Block: Git remote operation against a Rancher remote is prohibited.',
        };
      }
    } catch (err) {
      return {
        decision: 'deny',
        reason: `Security Policy Violation: Failed to check git remote safety configuration. Error: ${err.message || err}`,
        systemMessage: '🔒 Security Block: Remote safety verification failed.',
      };
    }
  }

  return { decision: 'allow' };
}

/**
 * Cleans a shell command string by stripping leading environment variable assignments.
 * Isolated in compliance with Single Responsibility Principle.
 * @param {string} command - The raw command string
 * @returns {string} The cleaned command string
 */
export function cleanCommandString(command) {
  if (typeof command !== 'string') {
    return '';
  }
  let commandClean = command.trim();
  while (true) {
    const next = commandClean.replace(/^[A-Za-z_][A-Za-z0-9_]*=(?:'[^']*'|"[^"]*"|\S+)\s+/, '');
    if (next === commandClean) {
      break;
    }
    commandClean = next;
  }
  return commandClean;
}

/**
 * Sanitizes stdout/stderr outputs to remove potential credentials or secrets.
 * @param {string} str - The string to sanitize
 * @returns {string} The sanitized string
 */
export function sanitizeOutput(str) {
  if (typeof str !== 'string') {
    return str;
  }
  return str
    .replace(/ghp_[A-Za-z0-9_]{36,255}/g, '[REDACTED_GH_TOKEN]')
    .replace(/github_token=[A-Za-z0-9_-]+/gi, 'github_token=[REDACTED]')
    .replace(/token=[A-Za-z0-9_-]+/gi, 'token=[REDACTED]')
    .replace(/https:\/\/[A-Za-z0-9_-]+:[A-Za-z0-9_-]+@/g, 'https://[REDACTED_USER_INFO]@');
}
