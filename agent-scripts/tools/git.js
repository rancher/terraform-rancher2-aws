#!/usr/bin/env node
import os from 'os';
import path from 'path';
import process from 'process';
import { fileURLToPath } from 'url';
import { verifyProactiveReview } from '../lib/approval.js';
import {
  calculateDiffHash,
  checkDefunctBranch,
  executeCommit,
  executeGit,
  executePush,
  gitAddAll,
  gitBranchList,
  gitBranchShowCurrent,
  gitCheckout,
  gitCheckoutNewBranch,
  gitCheckoutPath,
  gitCloneDepth1,
  gitCloneDepth1NoCheckout,
  gitDiff,
  gitDiffCachedNameOnly,
  gitDiffCachedQuiet,
  gitDiffFileContext,
  gitDiffHeadNameOnly,
  gitDiffStaged,
  gitDiffStagedContext,
  gitFetchQuiet,
  gitLogLastBody,
  gitLogLastSubject,
  gitLsFilesOthersExcludeStandard,
  gitMergeBaseIsAncestor,
  gitRemoteGetUrl,
  gitRemoteVerbose,
  gitRevParseBranch,
  gitRevParseGitDir,
  gitRevParseHead,
  gitRevParseShowToplevel,
  gitRevParseVerify,
  gitStashList,
  gitStashPop,
  gitStashPush,
  gitStatusPorcelain,
  gitSwitch,
  syncDefaultBranch,
  verifyPushSafety,
  verifyRemoteAncestry,
  verifySafeGitCommand,
  verifyStagingLimits,
  cleanCommandString,
  popStashByMessage,
  runAutomatedCommitAndPush,
  sanitizeOutput,
  syncUpstreamDefaultBranch,
} from '../lib/git.js';

export {
  calculateDiffHash,
  checkDefunctBranch,
  executeCommit,
  executeGit,
  executePush,
  gitAddAll,
  gitBranchList,
  gitBranchShowCurrent,
  gitCheckout,
  gitCheckoutNewBranch,
  gitCheckoutPath,
  gitCloneDepth1,
  gitCloneDepth1NoCheckout,
  gitDiff,
  gitDiffCachedNameOnly,
  gitDiffCachedQuiet,
  gitDiffFileContext,
  gitDiffHeadNameOnly,
  gitDiffStaged,
  gitDiffStagedContext,
  gitFetchQuiet,
  gitLogLastBody,
  gitLogLastSubject,
  gitLsFilesOthersExcludeStandard,
  gitMergeBaseIsAncestor,
  gitRemoteGetUrl,
  gitRemoteVerbose,
  gitRevParseBranch,
  gitRevParseGitDir,
  gitRevParseHead,
  gitRevParseShowToplevel,
  gitRevParseVerify,
  gitStashList,
  gitStashPop,
  gitStashPush,
  gitStatusPorcelain,
  gitSwitch,
  syncDefaultBranch,
  verifyPushSafety,
  verifyRemoteAncestry,
  verifySafeGitCommand,
  verifyStagingLimits,
  cleanCommandString,
  popStashByMessage,
  runAutomatedCommitAndPush,
  sanitizeOutput,
  syncUpstreamDefaultBranch,
};

function showHelp() {
  console.log(`Usage: git.js <command> [args...]

Commands:
  current-branch
  remotes
  verify-push-safety <remoteName>
  execute-push <remoteName> <branch> <forcePush: true|false>
  execute-commit <commitMsg> <branch>
  verify-staging-limits
  verify-remote-ancestry <branch>
  commit-push [-m "COMMIT_MESSAGE"] [-f|--force]
  execute <gitArgs...>
  help, -h, --help                   Show this help message`);
  process.exit(0);
}

// Support multi-call binary execution from the command line
async function main() {
  const command = process.argv[2];
  const cwd = process.cwd();

  try {
    if (!command || command === 'help' || command === '-h' || command === '--help') {
      showHelp();
    } else if (command === 'current-branch') {
      console.log(await gitBranchShowCurrent(cwd));
    } else if (command === 'remotes') {
      console.log(await gitRemoteVerbose(cwd));
    } else if (command === 'verify-push-safety') {
      await verifyPushSafety(process.argv[3], cwd);
    } else if (command === 'execute-push') {
      await executePush(process.argv[3], process.argv[4], process.argv[5] === 'true', cwd);
    } else if (command === 'execute-commit') {
      await executeCommit(process.argv[3], process.argv[4], cwd);
    } else if (command === 'verify-staging-limits') {
      await verifyStagingLimits(cwd);
    } else if (command === 'verify-remote-ancestry') {
      await verifyRemoteAncestry(process.argv[3], cwd);
    } else if (command === 'commit-push') {
      let commitMsg = '';
      let forcePush = false;
      const args = process.argv.slice(3);
      for (let i = 0; i < args.length; i++) {
        if (args[i] === '-f' || args[i] === '--force') {
          forcePush = true;
        } else if (args[i] === '-m') {
          commitMsg = args[++i];
        }
      }
      if (!commitMsg) {
        console.error('Error: Commit message is required. Specify using -m "message".');
        process.exit(1);
      }

      try {
        await gitRevParseShowToplevel(cwd);
      } catch (err) {
        console.error(`Error: git is required but not installed or not in a git repository: ${err.message}`);
        process.exit(1);
      }

      // Determine targetDir for state revocation on failure
      let repoName;
      try {
        repoName = path.basename(await gitRevParseShowToplevel(cwd));
      } catch {
        repoName = path.basename(cwd);
      }
      const home = os.homedir() || '/tmp';
      const targetDir = process.env.AGENT_STATE_DIR || path.join(home, '.gemini/tmp', repoName);

      try {
        const activeBranch = await gitBranchShowCurrent(cwd);
        await checkDefunctBranch(activeBranch, cwd);
        await verifyProactiveReview(cwd);

        try {
          await gitDiffCachedQuiet(cwd);
          console.error(
            "Error: No changes are currently staged for commit. Please stage your changes first using 'git add <files>...'.",
          );
          process.exit(1);
        } catch (err) {
          // Expected exception from gitDiffCachedQuiet when staging has changes.
          // This is a standard exit code inversion test, so we safely handle the exception here.
          console.log(`::notice::Active staged changes verified (exit code inversion passed: ${err.message || err})`);
        }
        await verifyStagingLimits(cwd);
        await syncDefaultBranch(activeBranch, cwd);
        if (!forcePush) {
          await verifyRemoteAncestry(activeBranch, cwd);
        }
        await executeCommit(commitMsg, activeBranch, cwd);
        await executePush('origin', activeBranch, forcePush, cwd);
      } catch (err) {
        // Enforce strict fail-safe state revocation on failure
        const { deleteFileSafe } = await import('../lib/file.js');
        await deleteFileSafe(path.join(targetDir, 'review-approval.json'));
        await deleteFileSafe(path.join(targetDir, 'require-ask-user.flag'));
        throw err;
      }
    } else if (command === 'execute') {
      const args = process.argv.slice(3);
      console.log(await executeGit(args, cwd));
    } else {
      console.error(`Unknown command: ${command}`);
      process.exit(1);
    }
  } catch (err) {
    console.error(`Git command failed: ${err.message}`);
    process.exit(1);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((err) => {
    console.error('::error::Fatal Git Tool Error:', err.stack || err.message);
    process.exit(1);
  });
}
