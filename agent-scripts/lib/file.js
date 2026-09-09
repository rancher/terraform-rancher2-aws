import { execFile } from 'child_process';
import crypto from 'crypto';
import fs, { promises as fsPromises } from 'fs';
import os from 'os';
import path from 'path';
import { promisify } from 'util';
import { findLatestActivePlan } from './plan.js';
import { gitRevParseShowToplevel } from './git.js';

const execFileAsync = promisify(execFile);

/**
 * Safely creates directories if they don't exist, and writes the file content asynchronously.
 */
export async function writeFileSafe(filePath, content, options = {}) {
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) {
    await fsPromises.mkdir(dir, { recursive: true });
  }
  await fsPromises.writeFile(filePath, content, options);
}

/**
 * Safely checks if a file or directory exists without throwing errors.
 */
export function fileExistsSafe(filePath) {
  try {
    return fs.existsSync(filePath);
  } catch {
    return false;
  }
}

/**
 * Safely deletes a file if it exists, without throwing errors asynchronously.
 */
export async function deleteFileSafe(filePath) {
  if (fs.existsSync(filePath)) {
    try {
      await fsPromises.rm(filePath, { force: true });
      return true;
    } catch (err) {
      console.error(`::error::Failed to delete ${filePath}: ${err.message}`);
    }
  }
  return false;
}

/**
 * Safely reads a file if it exists, otherwise returns null asynchronously.
 */
export async function readFileSafe(filePath, encoding = 'utf-8') {
  if (!fs.existsSync(filePath)) {
    return null;
  }
  try {
    return await fsPromises.readFile(filePath, encoding);
  } catch (err) {
    console.error(`::error::Failed to read ${filePath}: ${err.message}`);
    return null;
  }
}

/**
 * Safely executes a script file asynchronously.
 */
export async function executeFileSafe(filePath, args = [], options = {}) {
  if (!fs.existsSync(filePath)) {
    console.error(`::error::Failed to execute ${filePath}: File not found.`);
    return null;
  }

  let cmd = filePath;
  let finalArgs = [...args];

  if (filePath.endsWith('.js')) {
    cmd = 'node';
    finalArgs = [filePath, ...args];
  } else if (filePath.endsWith('.sh') || filePath.endsWith('.bash')) {
    cmd = 'bash';
    finalArgs = [filePath, ...args];
  }

  const finalOptions = {
    encoding: 'utf-8',
    cwd: path.dirname(path.resolve(filePath)),
    ...options,
  };

  try {
    const { stdout } = await execFileAsync(cmd, finalArgs, finalOptions);
    return stdout;
  } catch (err) {
    console.error(`::error::Failed to execute ${filePath}: ${err.message}`);
    if (err.stdout && err.stdout.toString().trim()) {
      console.error(`::error::Stdout:\n${err.stdout.toString().trim()}`);
    }
    if (err.stderr && err.stderr.toString().trim()) {
      console.error(`::error::Stderr:\n${err.stderr.toString().trim()}`);
    }
    throw err;
  }
}

export function extractPlanContent(promptText) {
  const matchCodeBlock = promptText.match(/```markdown\n([\s\S]*?)\n```/);
  if (matchCodeBlock) {
    return matchCodeBlock[1];
  } else {
    const hashIdx = promptText.indexOf('# ');
    if (hashIdx !== -1) {
      return promptText.substring(hashIdx);
    }
  }
  return '';
}

export async function savePlanContent(targetDir, planContent) {
  let activePlan = findLatestActivePlan(targetDir);
  if (!activePlan && planContent) {
    let activeSessions = [];
    try {
      if (fs.existsSync(targetDir) && (await fsPromises.stat(targetDir)).isDirectory()) {
        activeSessions = await fsPromises.readdir(targetDir);
      }
    } catch (err) {
      console.log(`::warning::savePlanContent failed to read target directory: ${err.message}`);
    }

    let plansDir = null;
    for (const session of activeSessions) {
      const plansPath = path.join(targetDir, session, 'plans');
      try {
        if (fs.existsSync(plansPath) && (await fsPromises.stat(plansPath)).isDirectory()) {
          plansDir = plansPath;
          break;
        }
      } catch {
        // Ignore stats/exists exceptions for specific session entries
      }
    }
    if (plansDir) {
      const matchTitle = planContent.match(/^#\s+(.+)$/m);
      const title = matchTitle ? matchTitle[1].trim().replace(/[^a-zA-Z0-9-_]/g, '') : 'Plan';
      activePlan = path.join(plansDir, `${title}.md`);
    }
  }

  if (planContent && activePlan) {
    try {
      await writeFileSafe(activePlan, planContent, { mode: 0o600 });
      console.error(`🔒 Hook Info: Successfully bypassed write block to save plan to ${activePlan}`);
    } catch (err) {
      console.log(`::error::Hook Error: Failed to write plan to ${activePlan}: ${err.message}`);
    }
  }
  return activePlan || findLatestActivePlan(targetDir);
}

// Calculate SHA-256 hash of a file's content
export async function calculateFileHash(filePath) {
  try {
    const content = await readFileSafe(filePath, null); // Provide null encoding to read as Buffer
    if (!content) {
      return null;
    }
    return crypto.createHash('sha256').update(content).digest('hex');
  } catch (err) {
    console.log(`::error::calculateFileHash failed {"message":"${err.message}"}`);
    return null;
  }
}

/**
 * Compares two paths using the system diff command safely bypassing the shell.
 * @param {string} path1
 * @param {string} path2
 * @param {object} options - Options including { isDir: boolean, stdio: string }
 * @returns {string} - The diff output
 */
export async function diffPaths(path1, path2, options = {}) {
  const { isDir = false, stdio = 'pipe', cwd = process.cwd() } = options;
  const absPath1 = path.resolve(cwd, path1);
  const absPath2 = path.resolve(cwd, path2);
  const args = isDir ? ['-ru', absPath1, absPath2] : ['-u', absPath1, absPath2];
  const { stdout } = await execFileAsync('diff', args, { encoding: 'utf-8', stdio, cwd });
  return stdout;
}

/**
 * Resolves the target temporary directory for the current repository workspace.
 * @param {string} [cwd] - Optional current working directory, defaults to process.cwd()
 * @returns {string} The absolute path to the target temporary directory.
 */
export async function resolveTargetDir(cwd = process.cwd()) {
  let homeDir = os.homedir();
  try {
    // Prefer os.userInfo().homedir to bypass any $HOME environment variable overrides (e.g. from Nix or sandboxes)
    homeDir = os.userInfo().homedir || homeDir;
  } catch (err) {
    // Fallback to os.homedir() if os.userInfo() fails
    console.warn(`⚠️  Hook Warning: os.userInfo() failed, falling back to os.homedir(): ${err.message}`);
  }

  let repoName;
  try {
    const topLevel = await gitRevParseShowToplevel(cwd);
    repoName = path.basename(topLevel);
  } catch (err) {
    console.error(`🔒 Hook Info: Failed to resolve git toplevel directory: ${err.message || err}`);
    repoName = path.basename(cwd) || 'generic-repo';
  }
  return path.resolve(homeDir, '.gemini/tmp', repoName);
}

/**
 * Registers global process exit traps to cleanly purge a sandbox directory on exit or signal.
 * Standardizes cleanup behavior across Level-3 orchestrators in compliance with architecture standards.
 * @param {string} sandboxPath - The path to the sandbox directory to purge.
 */
export function registerCleanupTraps(sandboxPath) {
  const cleanup = () => {
    if (sandboxPath && fs.existsSync(sandboxPath)) {
      try {
        fs.rmSync(sandboxPath, { recursive: true, force: true });
        console.error(`🧹 Secure Sandbox Cleaned Up: ${sandboxPath}`);
      } catch (err) {
        console.warn(`⚠️ Cleanup failed for ${sandboxPath}: ${err.message}`);
      }
    }
  };

  process.on('exit', cleanup);
  process.on('SIGINT', () => {
    cleanup();
    process.exit(1);
  });
  process.on('SIGTERM', () => {
    cleanup();
    process.exit(1);
  });
  process.on('uncaughtException', (err) => {
    console.error(`::error::Fatal Uncaught Exception: ${err.stack || err.message}`);
    cleanup();
    process.exit(1);
  });
}

/**
 * Safely creates a unique temporary directory asynchronously.
 * @param {string} prefix - Prefix for the temp directory.
 * @returns {Promise<string>} The path to the created directory.
 */
export async function mkdtempSafe(prefix) {
  return await fsPromises.mkdtemp(prefix);
}

/**
 * Safely copies a file asynchronously.
 * @param {string} src - Source file path.
 * @param {string} dest - Destination file path.
 */
export async function copyFileSafe(src, dest) {
  await fsPromises.copyFile(src, dest);
}

/**
 * Safely reads a directory asynchronously.
 * @param {string} dirPath - Directory path.
 * @returns {Promise<string[]>} List of files in the directory.
 */
export async function readdirSafe(dirPath) {
  return await fsPromises.readdir(dirPath);
}

/**
 * Safely gets file/directory stats asynchronously.
 * @param {string} filePath - Path to file or directory.
 * @returns {Promise<fs.Stats>} The stats object.
 */
export async function statSafe(filePath) {
  return await fsPromises.stat(filePath);
}
