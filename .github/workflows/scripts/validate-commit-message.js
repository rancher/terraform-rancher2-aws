import { execSync } from 'child_process';

/**
 * Validates a single commit title against Conventional Commits and strict product-boundary semver rules.
 * This function is fully exported and modular for clean reuse across different workflows and scripts!
 */
export function validateCommitTitle(title, affectsProduct, isMerge) {
  // Allow and skip standard git merge commits (which have multiple parents)
  if (isMerge) {
    return { valid: true, isMerge: true };
  }

  const CONVENTIONAL_COMMIT_REGEXP =
    /^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(?:\([^)]+\))?(!?): .+/i;

  if (!CONVENTIONAL_COMMIT_REGEXP.test(title)) {
    return {
      valid: false,
      reason: `Commit message title does not follow Conventional Commits format. Expected "type: description" or "type(scope): description". Got: "${title}"`,
    };
  }

  // Extract type and exclamation indicator from title
  const match = title.match(/^([a-z]+)(?:\([^)]+\))?(!?):/i);
  const type = match[1].toLowerCase();
  const hasExclamation = match[2] === '!';

  // Enforce strict product-boundary check for semver safety (non-product changes cannot use feat, refactor, or !)
  if (!affectsProduct) {
    if (type === 'feat' || type === 'refactor' || hasExclamation) {
      return {
        valid: false,
        reason: `Non-product change (outside 'internal/') must NOT use 'feat', 'refactor', or '!' breaking-change indicators (which trigger incorrect minor/major semver bumps on release-please).`,
      };
    }
  }

  return { valid: true };
}

/**
 * Main GHA Script runner function executed inside pull_request.yaml
 */
export default async ({ github, context, core, process }) => {
  const prNumber = process.env.PR_NUMBER || context.payload.pull_request?.number || context.issue.number;
  if (!prNumber) {
    throw new Error('Could not determine pull request number from context');
  }

  const owner = context.repo.owner;
  const repo = context.repo.repo;

  core.info(`Retrieving commit messages for PR #${prNumber}...`);
  const commits = await github.paginate(github.rest.pulls.listCommits, {
    owner,
    repo,
    pull_number: prNumber,
  });

  core.info(`Retrieving changed files list for PR #${prNumber}...`);
  const files = await github.paginate(github.rest.pulls.listFiles, {
    owner,
    repo,
    pull_number: prNumber,
  });

  const affectsProduct = files.some((f) => f.filename.startsWith('internal/'));
  core.info(`PR #${prNumber} affects product (contains changes inside 'internal/'): ${affectsProduct}`);

  let allPassed = true;

  for (const c of commits) {
    const message = c.commit.message;
    const subjectLine = message.split('\n')[0].trim();
    core.info(`--------------------------------------------------`);
    core.info(`Checking message: "${subjectLine}"`);

    // 1. Empty Check
    if (!subjectLine) {
      core.error('Error: Commit message subject line is empty.');
      allPassed = false;
      continue;
    }

    // 2. Length Check
    if (subjectLine.length > 100) {
      core.error(`Error: Commit message subject line should be less than 100 characters, found ${subjectLine.length}.`);
      allPassed = false;
      continue;
    }

    // Determine if this is a standard git merge commit (any commit with 2 or more parent commits starting with "Merge")
    const isMergeCommit = c.parents && c.parents.length > 1;
    const isMerge = isMergeCommit && /^Merge\s+/i.test(subjectLine);

    // 3. Prefix & Semver Check
    const { valid, reason } = validateCommitTitle(subjectLine, affectsProduct, isMerge);
    if (!valid) {
      core.error(`Error: ${reason}`);
      allPassed = false;
      continue;
    }

    // 4. Spell Check
    if (!isMerge) {
      try {
        const cspellCmd = `${process.env.GITHUB_WORKSPACE}/.github/workflows/scripts/nix-run.sh cspell stdin --quiet --words-only`;
        const words = execSync(cspellCmd, {
          input: subjectLine,
          stdio: ['pipe', 'pipe', 'ignore'],
        })
          .toString()
          .trim();

        if (words) {
          core.error(`Error: Commit message contains spelling errors on: ${words.replace(/\r?\n/g, ', ')}`);
          allPassed = false;
          continue;
        }
      } catch (err) {
        core.warning(`Spell check execution skipped or failed: ${err.message}`);
      }
    }

    core.info(`✅ Message "${subjectLine}" passed all checks.`);
  }

  if (!allPassed) {
    core.setFailed('Commit message validation failed. Please correct your commit messages.');
  } else {
    core.info('==================================================');
    core.info('All commit messages successfully validated!');
  }
};
