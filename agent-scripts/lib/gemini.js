import { spawn } from 'child_process';
import os from 'os';
import path from 'path';

/**
 * Helper to stream Gemini subagent output in real-time inside a target sandbox directory.
 * Overrides the HOME env variable to bypass our strict Gated Lifecycle hooks.
 * @param {string} prompt
 * @param {string} subagent
 * @param {string} targetSandboxDir
 * @returns {Promise<string>}
 */
export function runGemini(prompt, subagent, targetSandboxDir, model = null, timeoutMs = 0, contextLabel = '') {
  return new Promise((resolve, reject) => {
    // Standard non-interactive headless invocation
    // Combine subagent and prompt into a single argument for -p to avoid positional argument error
    const args = ['-p', `${subagent}: ${prompt}`, '--skip-trust'];
    if (model) {
      args.push('--model', model);
    }

    const child = spawn('gemini', args, {
      cwd: targetSandboxDir,
      timeout: timeoutMs,
      stdio: ['ignore', 'pipe', 'pipe'],
      env: {
        ...process.env,
        HOME: targetSandboxDir,
        GEMINI_CLI_HOME: os.homedir(),
        CI: 'true',
      },
    });

    let stdout = '';
    let stderr = '';

    const cleanLabel = subagent.replace('@', '');
    const prefix = contextLabel ? `::sub-agent_${cleanLabel}[${contextLabel}]:: ` : `::sub-agent_${cleanLabel}:: `;

    child.on('error', (err) => {
      reject(new Error(`Failed to spawn gemini process: ${err.message}`));
    });

    let stdoutBuffer = '';
    child.stdout.on('data', (data) => {
      stdoutBuffer += data.toString();
      const lines = stdoutBuffer.split('\n');
      stdoutBuffer = lines.pop(); // Keep incomplete line in buffer
      lines.forEach((line) => {
        process.stdout.write(`${prefix}${line}\n`);
      });
      stdout += data.toString();
    });

    let stderrBuffer = '';
    child.stderr.on('data', (data) => {
      stderrBuffer += data.toString();
      const lines = stderrBuffer.split('\n');
      stderrBuffer = lines.pop(); // Keep incomplete line in buffer
      lines.forEach((line) => {
        process.stderr.write(`${prefix}${line}\n`);
      });
      stderr += data.toString();
    });

    child.on('close', (code) => {
      // Flush remaining buffers
      if (stdoutBuffer) {
        process.stdout.write(`${prefix}${stdoutBuffer}\n`);
      }
      if (stderrBuffer) {
        process.stderr.write(`${prefix}${stderrBuffer}\n`);
      }
      if (code !== 0) {
        reject(new Error(`gemini process exited with code ${code}.\nStderr: ${stderr}`));
      } else {
        resolve(stdout);
      }
    });
  });
}

/**
 * Wrapper around runGemini to support exponential backoff on model rate limits.
 * @param {string} prompt
 * @param {string} subagent
 * @param {string} targetSandboxDir
 * @param {number} maxAttempts
 * @returns {Promise<string>}
 */
export async function runGeminiWithRetry(
  prompt,
  subagent,
  targetSandboxDir,
  maxAttempts = 5,
  model = null,
  timeoutMs = 0,
  contextLabel = '',
) {
  let attempt = 0;
  let delay = 5000; // Start at 5 seconds

  while (attempt < maxAttempts) {
    attempt++;
    try {
      const result = await runGemini(prompt, subagent, targetSandboxDir, model, timeoutMs, contextLabel);
      return result;
    } catch (err) {
      const errMsg = err.message || '';
      const isRateLimit =
        errMsg.includes('exhausted your capacity') ||
        errMsg.includes('429') ||
        errMsg.includes('ResourceExhausted') ||
        errMsg.includes('quota');

      if (isRateLimit && attempt < maxAttempts) {
        console.warn(
          `⚠️  [Sandbox] Rate limited on ${subagent} inside ${path.basename(targetSandboxDir)} (Attempt ${attempt}/${maxAttempts}). Retrying in ${delay / 1000}s...`,
        );
        await new Promise((resolve) => setTimeout(resolve, delay));
        delay *= 2; // Exponential backoff: 5s, 10s, 20s, 40s...
      } else {
        throw err; // Non-rate-limit error or max attempts reached
      }
    }
  }
}
