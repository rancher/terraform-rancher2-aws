import fs from 'fs';
import os from 'os';
import path from 'path';
import process from 'process';
import { promisify } from 'util';
import { execFile } from 'child_process';

const execFileAsync = promisify(execFile);

async function executeFileAsyncHelper(filePath, args = [], options = {}) {
  const isGlobalCmd = !filePath.includes('/') && !filePath.includes('\\');
  if (!isGlobalCmd && !fs.existsSync(filePath)) {
    throw new Error(`Failed to execute ${filePath}: File not found.`);
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

  try {
    const { stdout, stderr } = await execFileAsync(cmd, finalArgs, options);
    return { success: true, stdout, stderr };
  } catch (err) {
    return {
      success: false,
      stdout: err.stdout || '',
      stderr: err.stderr || '',
      error: err,
    };
  }
}

export async function runLint() {
  const filePath = path.resolve(process.cwd(), '.github/workflows/scripts/lint.sh');
  return executeFileAsyncHelper(filePath, ['all', '--fix']);
}

export async function runProductTests() {
  const filePath = path.resolve(process.cwd(), '.github/workflows/scripts/test.sh');
  return executeFileAsyncHelper(filePath, ['all']);
}

export async function runAgentTests() {
  return executeFileAsyncHelper('npm', ['test'], { cwd: process.cwd() });
}

export function parseTestLogs(options = {}) {
  let { file } = options;
  const { noColor, failedOnly, passedOnly } = options;

  if (failedOnly && passedOnly) {
    throw new Error('failedOnly and passedOnly options are mutually exclusive.');
  }

  // Determine colors
  const useColor = !noColor && !process.env.NO_COLOR;
  const RED = useColor ? '\x1b[1;31m' : '';
  const GREEN = useColor ? '\x1b[1;32m' : '';
  const YELLOW = useColor ? '\x1b[1;33m' : '';
  const BLUE = useColor ? '\x1b[1;34m' : '';
  const NC = useColor ? '\x1b[0m' : '';
  const CHECK_MARK = useColor ? '\x1b[1;32m✓\x1b[0m' : '✓';
  const CROSS_MARK = useColor ? '\x1b[1;31m✗\x1b[0m' : '✗';

  // Locate file if not provided
  if (!file) {
    const tempDir = os.tmpdir();
    try {
      const files = fs.readdirSync(tempDir);
      const testLogs = files
        .filter((f) => f.endsWith('_test.log'))
        .map((f) => {
          const fullPath = path.join(tempDir, f);
          const stat = fs.statSync(fullPath);
          return { path: fullPath, mtime: stat.mtimeMs };
        })
        .sort((a, b) => b.mtime - a.mtime);

      if (testLogs.length > 0) {
        file = testLogs[0].path;
      }
    } catch {
      // Ignore directory read errors
    }
  }

  if (!file || !fs.existsSync(file)) {
    return {
      success: false,
      output: `${RED}[ERROR]${NC} No valid test log file found or specified.`,
    };
  }

  let output = `${BLUE}=== Parsing Test Log: ${file} ===${NC}\n`;
  let fileContent;
  try {
    fileContent = fs.readFileSync(file, 'utf-8');
  } catch (err) {
    return {
      success: false,
      output: `${RED}[ERROR]${NC} Failed to read log file: ${err.message}`,
    };
  }

  const lines = fileContent.split('\n').filter(Boolean);
  const passedTests = [];
  const failedTests = [];
  const failedPkgs = [];

  for (const line of lines) {
    try {
      const event = JSON.parse(line);
      if (event.Action === 'pass' && event.Test) {
        passedTests.push({ name: event.Test, elapsed: event.Elapsed || 0 });
      } else if (event.Action === 'fail') {
        if (event.Test) {
          failedTests.push({ name: event.Test, elapsed: event.Elapsed || 0 });
        } else if (event.Package) {
          failedPkgs.push({ name: event.Package, elapsed: event.Elapsed || 0 });
        }
      }
    } catch {
      // Ignore invalid JSON lines
    }
  }

  // Deduplicate and sort
  const uniquePassed = Array.from(new Map(passedTests.map((t) => [t.name, t])).values()).sort((a, b) =>
    a.name.localeCompare(b.name),
  );
  const uniqueFailedTests = Array.from(new Map(failedTests.map((t) => [t.name, t])).values()).sort((a, b) =>
    a.name.localeCompare(b.name),
  );
  const uniqueFailedPkgs = Array.from(new Map(failedPkgs.map((t) => [t.name, t])).values()).sort((a, b) =>
    a.name.localeCompare(b.name),
  );

  const passedCount = uniquePassed.length;
  const failedTestCount = uniqueFailedTests.length;
  const failedPkgCount = uniqueFailedPkgs.length;
  const totalFailures = failedTestCount + failedPkgCount;

  if (!failedOnly) {
    output += `\n${GREEN}PASSED TESTS (${passedCount}):${NC}\n`;
    if (passedCount > 0) {
      for (const t of uniquePassed) {
        output += `  ${CHECK_MARK} ${t.name} (${t.elapsed}s)\n`;
      }
    } else {
      output += '  None\n';
    }
  }

  if (!passedOnly) {
    output += `\n${RED}FAILED ITEMS (${totalFailures}):${NC}\n`;
    if (failedTestCount > 0) {
      output += `  ${YELLOW}Individual Tests:${NC}\n`;
      for (const t of uniqueFailedTests) {
        output += `    ${CROSS_MARK} ${t.name} (${t.elapsed}s)\n`;
      }
    }
    if (failedPkgCount > 0) {
      output += `  ${YELLOW}Packages/Builds:${NC}\n`;
      for (const p of uniqueFailedPkgs) {
        output += `    ${CROSS_MARK} Package: ${p.name} (${p.elapsed}s)\n`;
      }
    }
    if (totalFailures === 0) {
      output += '  None\n';
    }
  }

  output += `\n${BLUE}=======================================${NC}\n`;
  if (totalFailures > 0) {
    output += `${RED}Overall Outcome: FAILED${NC}\n`;
    return { success: false, output };
  } else {
    output += `${GREEN}Overall Outcome: SUCCESS${NC}\n`;
    return { success: true, output };
  }
}

export async function runPreReviewTests() {
  let output = '=== PRE-REVIEW TESTING ===\n\n';
  let overallSuccess = true;
  let failureDetails = '';

  // 1. Full Workspace Lint
  output += '--- Running Full Workspace Lint (lint.sh all) ---\n';
  const lintResult = await runLint();
  if (lintResult.success) {
    output += (lintResult.stdout || '') + '\n🟢 Full workspace lint passed.\n\n';
  } else {
    overallSuccess = false;
    const details =
      `❌ Full workspace lint failed.\n` +
      (lintResult.stdout ? `Stdout:\n${lintResult.stdout}\n` : '') +
      (lintResult.stderr ? `Stderr:\n${lintResult.stderr}\n` : '') +
      `Error Details: ${lintResult.error ? lintResult.error.message : 'Unknown error'}\n`;
    output += details + '\n';
    failureDetails += details + '\n';
  }

  // 2. Full Workspace Tests
  output += '--- Running Full Workspace Tests (test.sh all) ---\n';
  const testResult = await runProductTests();
  if (testResult.success) {
    output += (testResult.stdout || '') + '\n🟢 Full workspace tests passed.\n\n';
  } else {
    overallSuccess = false;
    const details =
      `❌ Full workspace tests failed.\n` +
      (testResult.stdout ? `Stdout:\n${testResult.stdout}\n` : '') +
      (testResult.stderr ? `Stderr:\n${testResult.stderr}\n` : '') +
      `Error Details: ${testResult.error ? testResult.error.message : 'Unknown error'}\n`;
    output += details + '\n';
    failureDetails += details + '\n';
  }

  // 3. Agent Script Tests
  output += '--- Running Agent Script Tests (npm test) ---\n';
  const agentResult = await runAgentTests();
  if (agentResult.success) {
    output += (agentResult.stdout || '') + '\n🟢 Agent script tests passed.\n\n';
  } else {
    overallSuccess = false;
    const details =
      `❌ Agent script tests failed.\n` +
      (agentResult.stdout ? `Stdout:\n${agentResult.stdout}\n` : '') +
      (agentResult.stderr ? `Stderr:\n${agentResult.stderr}\n` : '') +
      `Error Details: ${agentResult.error ? agentResult.error.message : 'Unknown error'}\n`;
    output += details + '\n';
    failureDetails += details + '\n';
  }

  if (overallSuccess) {
    return { success: true, output };
  } else {
    return { success: false, failureOutput: failureDetails || output };
  }
}
