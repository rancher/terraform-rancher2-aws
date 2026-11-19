import { exec, execFile } from 'node:child_process';
import path from 'node:path';
import { promisify } from 'node:util';
import { fileAffectsProduct, getProductRoots, validateCommitTitle } from '../../skills/git/scripts/commit.js';

const execAsync = promisify(exec);
const execFileAsync = promisify(execFile);

/**
 * Gets the current unstaged and staged git diff.
 * @returns {Promise<string>} The git diff
 */
export async function getGitDiff() {
  const { stdout } = await execAsync('git diff --no-ext-diff HEAD', { maxBuffer: 10 * 1024 * 1024 });
  return stdout;
}

/**
 * Checks if the cached (staged) or active changes affect product files.
 * @returns {Promise<boolean>}
 */
export async function affectsProductFiles() {
  const { stdout: diffFiles } = await execAsync('git diff --no-ext-diff --name-only HEAD', {
    maxBuffer: 10 * 1024 * 1024,
  });
  const changedFiles = diffFiles
    .split('\n')
    .map((f) => f.trim())
    .filter(Boolean);
  const roots = await getProductRoots();
  return changedFiles.some((f) => fileAffectsProduct(f, roots));
}

/**
 * Validates a candidate commit message against the repository rules.
 * @param {string} message - The commit message to validate
 * @returns {Promise<{valid: boolean, reason?: string}>}
 */
export async function validateMessage(message) {
  const isProduct = await affectsProductFiles();
  const result = validateCommitTitle(message, isProduct, false);
  return result;
}

/**
 * Stages all changes and executes a signed, validated git commit.
 * @param {string} commitMessage - The message to commit with
 * @returns {Promise<{stdout: string, stderr: string}>} The commit result
 */
export async function stageAndCommit(commitMessage) {
  // Prevent commits directly to the main branch
  const { stdout: branchOutput } = await execAsync('git rev-parse --abbrev-ref HEAD');
  if (branchOutput.trim() === 'main') {
    throw new Error('Commits directly to the "main" branch are not allowed.');
  }

  // Get explicitly modified and untracked files
  const scriptPath = path.join(process.cwd(), '.gemini/skills/git/scripts/get_modified_paths.js');
  const { stdout: pathsOutput } = await execAsync(`node "${scriptPath}"`);
  const modifiedPaths = pathsOutput
    .split('\n')
    .map((p) => p.trim())
    .filter(Boolean);

  if (modifiedPaths.length > 0) {
    // Stage files in chunks to prevent E2BIG (Argument list too long) OS errors
    const chunkSize = 100;
    for (let i = 0; i < modifiedPaths.length; i += chunkSize) {
      const chunk = modifiedPaths.slice(i, i + chunkSize);
      await execFileAsync('git', ['add', ...chunk], { maxBuffer: 10 * 1024 * 1024 });
    }
  }

  // Verify the message before committing
  const validation = await validateMessage(commitMessage);
  if (!validation.valid) {
    throw new Error(`Commit message validation failed: ${validation.reason}`);
  }

  // Perform signed and signed-off commit
  const { stdout, stderr } = await execFileAsync('git', ['commit', '-s', '-S', '-m', commitMessage], {
    maxBuffer: 10 * 1024 * 1024,
  });
  return { stdout, stderr };
}

/**
 * Strips volatile diff metadata (index hashes and chunk header line numbers)
 * while preserving diff content whitespace and hunk location context,
 * so that cryptographic diff hashing is resilient to line number shifts.
 * @param {string} diff - The unified git diff string
 * @returns {string} The sanitized diff string
 */
export function stripDiffMetadata(diff) {
  if (typeof diff !== 'string' || !diff) {
    return '';
  }
  return diff
    .split(/\r?\n/)
    .filter((line) => !line.startsWith('index '))
    .map((line) => line.replace(/^@@\s+-\d+(?:,\d+)?\s+\+\d+(?:,\d+)?\s+@@/, '@@ @@'))
    .join('\n');
}
