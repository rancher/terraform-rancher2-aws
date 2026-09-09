#!/usr/bin/env node
import crypto from 'crypto';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { fileURLToPath } from 'url';
import { revokeSignature, verifyPlanGate, healApprovalState } from './tools/approval.js';
import {
  deleteFileSafe,
  readFileSafe,
  resolveTargetDir,
  writeFileSafe,
  registerCleanupTraps,
  mkdtempSafe,
  copyFileSafe,
  readdirSafe,
  statSafe,
  fileExistsSafe,
} from './tools/file.js';
import { runGeminiWithRetry } from './tools/gemini.js';
import {
  gitDiffHeadNameOnly,
  gitDiffStagedContext,
  gitAddAll,
  gitBranchShowCurrent,
  gitDiff,
  executeGit,
} from './tools/git.js';
import { readState, setLock, setPhase } from './tools/state.js';
import { runPreReviewTests } from './tools/test.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REVIEW_MODEL = process.env.GEMINI_MODEL || null;

const REVIEW_CONFIG = {
  batchSize: parseInt(process.env.GEMINI_REVIEW_BATCH_SIZE || '10', 10),
  staggerDelay: parseInt(process.env.GEMINI_REVIEW_STAGGER_DELAY || '6000', 10),
};

let sandboxDir = null;

process.on('unhandledRejection', (reason) => {
  console.log('::error::Unhandled Promise Rejection: ' + (reason.stack || reason));
  if (sandboxDir && fs.existsSync(sandboxDir)) {
    try {
      fs.rmSync(sandboxDir, { recursive: true, force: true });
    } catch (err) {
      console.warn(`Failed to clean up sandbox on unhandled rejection: ${err.message}`);
    }
  }
  process.exit(1);
});

function cleanMarkdownBlocks(rawText) {
  let cleaned = rawText.trim();
  if (cleaned.startsWith('```')) {
    const firstNewline = cleaned.indexOf('\n');
    cleaned = cleaned.substring(firstNewline + 1);
  }
  if (cleaned.endsWith('```')) {
    cleaned = cleaned.substring(0, cleaned.length - 3);
  }
  return cleaned.trim();
}

// Unused remediation helpers removed for streamlined PM-based review loop

function getStandardsFile(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  switch (ext) {
    case '.go':
      return 'docs/development/reference/Go.md';
    case '.js':
    case '.mjs':
    case '.cjs':
      return 'docs/development/reference/JavaScript.md';
    case '.sh':
      return 'docs/development/reference/ShellScripts.md';
    case '.md':
      return 'docs/development/reference/Documentation.md';
    case '.yml':
    case '.yaml':
      return 'docs/development/reference/Workflows.md';
    case '.tf':
      return 'docs/development/reference/Terraform.md';
    default:
      return 'docs/development/reference/CodingStandards.md';
  }
}

// Helper to find all files recursively
async function getFilesRecursively(dir) {
  let results = [];
  const list = await readdirSafe(dir);
  for (const file of list) {
    const filePath = path.join(dir, file);
    let stat;
    try {
      stat = await statSafe(filePath);
    } catch (err) {
      console.log(`::warning::Inaccessible file or directory ${filePath}: ${err.message}`);
      continue; // Ignore inaccessible files
    }
    if (stat && stat.isDirectory()) {
      if (file !== 'node_modules' && file !== '.git' && file !== 'bin' && file !== 'test') {
        const nested = await getFilesRecursively(filePath);
        results = results.concat(nested);
      }
    } else {
      const ext = path.extname(file);
      if (
        file !== 'go.sum' &&
        file !== 'package-lock.json' &&
        ext !== '.png' &&
        ext !== '.jpg' &&
        ext !== '.svg' &&
        ext !== '.gif'
      ) {
        results.push(filePath);
      }
    }
  }
  return results;
}

async function revokeReviewState(targetDir) {
  await revokeSignature(targetDir, 'review-approval.json');
  await deleteFileSafe(path.join(targetDir, 'require-ask-user.flag'));
  console.log('::notice::🗑️ Revoked review approval and state flag files due to non-compliance.');

  const state = await readState(targetDir);
  if (state && state.locked && state.keyTool === 'ask_user') {
    await setLock(targetDir, false);
    console.log('::notice::🗑️ Revoked locked state flag due to non-compliance.');
  }
}

async function verifyGates(targetDir) {
  console.log('::notice::Verifying planning gate status...');
  const planHash = await verifyPlanGate(targetDir);
  if (!planHash) {
    console.log('::error::❌ Planning gate is missing or invalid! Obtain plan approval first.');
    await healApprovalState(targetDir, 'plan');
    await revokeReviewState(targetDir);
    process.exit(1);
  }
  return planHash;
}

async function runTests(targetDir) {
  console.log('::notice::Running pre-review tests...');
  const testResult =
    process.env.GEMINI_TEST === 'true' ? await runPreReviewTests(() => 'mock passed') : await runPreReviewTests();
  if (!testResult.success) {
    console.log(`::error::❌ Pre-review testing failed: ${testResult.failureOutput.replace(/\n/g, ' ')}`);
    revokeReviewState(targetDir);
    process.exit(1);
  }
  console.log('::notice::' + testResult.output);
  console.log('::notice::🟢 Pre-review tests passed.');
}

async function identifyFilesToReview(argv, targetDir) {
  let outputFilePath = path.join(targetDir, 'review-report.md');
  const pathArgs = argv.filter((arg) => !arg.startsWith('-'));

  const pathArg = pathArgs[0];
  const isCustomPathMode = !!pathArg;

  if (outputFilePath) {
    if (outputFilePath.startsWith('~')) {
      outputFilePath = path.join(os.homedir(), outputFilePath.slice(1));
    }
    outputFilePath = path.resolve(outputFilePath);
    console.log(`::notice::💾 Final report will be saved to: ${outputFilePath}`);
  }

  let activeDiff;
  let filteredFiles;
  let isEntireFileReview = false;

  if (isCustomPathMode) {
    if (!fileExistsSafe(pathArg)) {
      console.log(`::error::❌ Error: Path not found: ${pathArg}`);
      await revokeReviewState(targetDir);
      process.exit(1);
    }
    const stat = await statSafe(pathArg);
    if (stat.isDirectory()) {
      console.log(`::notice::🔍 Directory Mode: Recursively reviewing entire files as written in: ${pathArg}`);
      filteredFiles = await getFilesRecursively(pathArg);
      activeDiff = `directory-review-of-${pathArg}`;
    } else {
      console.log(`::notice::🔍 Single File Mode: Reviewing entire file as written: ${pathArg}`);
      filteredFiles = [pathArg];
      activeDiff = (await readFileSafe(pathArg)) || '';
    }
    isEntireFileReview = true;
  } else {
    console.log('::notice::Staging all workspace changes (git add -A)...');
    await gitAddAll();

    const currentBranch = await gitBranchShowCurrent();
    let filesOutput;
    if (currentBranch !== 'main' && currentBranch) {
      console.log(`::notice::Calculating diff against main branch (git diff main)...`);
      activeDiff = await gitDiff('main');
      filesOutput = await executeGit(['diff', 'main', '--name-only']);
    } else {
      console.log('::notice::Identifying changed files relative to HEAD...');
      activeDiff = await gitDiffStagedContext();
      filesOutput = await gitDiffHeadNameOnly();
    }

    const files = filesOutput ? filesOutput.split('\n') : [];

    filteredFiles = files.filter((f) => {
      if (!f) {
        return false;
      }
      if (!fileExistsSafe(f)) {
        return false;
      }
      const ext = path.extname(f);
      return (
        f !== 'go.sum' &&
        f !== 'package-lock.json' &&
        ext !== '.png' &&
        ext !== '.jpg' &&
        ext !== '.svg' &&
        ext !== '.gif' &&
        ext !== '.lock' &&
        !f.startsWith('.git/') &&
        !f.startsWith('.gemini/') &&
        !f.startsWith('bin/') &&
        !f.startsWith('test/')
      );
    });

    if (filteredFiles.length === 0) {
      console.log('::notice::🟢 No modified files to review.');
      process.exit(0);
    }

    console.log(`::notice::Found ${filteredFiles.length} files to review: ${filteredFiles.join(', ')}`);
  }

  return { outputFilePath, filteredFiles, activeDiff, isEntireFileReview };
}

async function runMapPhase(filteredFiles, isEntireFileReview, targetDir) {
  console.log(`::notice::[MAP] Running heads-down coder and lead architect reviews`);

  // Gather unique standards for the modified files
  const requiredStandards = new Set(filteredFiles.map(getStandardsFile));

  // Chunk files into batches to maintain deep review quality without hitting output token limits
  const fileBatches = [];
  for (let i = 0; i < filteredFiles.length; i += REVIEW_CONFIG.batchSize) {
    fileBatches.push(filteredFiles.slice(i, i + REVIEW_CONFIG.batchSize));
  }

  // Build the combined content
  let fullContent = '';
  if (isEntireFileReview) {
    for (const file of filteredFiles) {
      const content = await readFileSafe(file);
      if (content && content.trim()) {
        fullContent += `--- File: ${file} ---\n${content}\n\n`;
      }
    }
  } else {
    fullContent = await gitDiffStagedContext();
  }

  if (!fullContent || !fullContent.trim()) {
    return [];
  }

  // 1. Parallel heads_down_coder for small file batches
  const fileWorkerPromises = fileBatches.map(async (batch, index) => {
    if (index > 0) {
      await new Promise((resolve) => setTimeout(resolve, index * REVIEW_CONFIG.staggerDelay));
    }

    let batchContent = '';
    if (isEntireFileReview) {
      for (const file of batch) {
        const content = await readFileSafe(file);
        if (content && content.trim()) {
          batchContent += `--- File: ${file} ---\n${content}\n\n`;
        }
      }
    }

    if (!batchContent.trim()) {
      return null;
    }

    const batchSandbox = await mkdtempSafe(path.join(sandboxDir, 'coder-batch-'));

    const standardNames = [];
    for (const stdPath of requiredStandards) {
      if (fileExistsSafe(stdPath)) {
        const stdName = path.basename(stdPath);
        await copyFileSafe(stdPath, path.join(batchSandbox, stdName));
        standardNames.push(stdName);
      }
    }

    if (standardNames.length === 0) {
      await writeFileSafe(
        path.join(batchSandbox, 'CodingStandards.md'),
        '# Default Standards\nEvaluate target files according to industry best practices.',
      );
      standardNames.push('CodingStandards.md');
    }

    const targetContentFile = path.join(batchSandbox, 'target_content.txt');
    await writeFileSafe(targetContentFile, batchContent);

    const prompt = `Please review the target content or diff provided in "target_content.txt". Refer to the following coding standards provided in your sandbox: ${standardNames.join(', ')}. You MUST process this batch sequentially, focusing strictly on one file at a time. Provide rapid-fire, highly-critical notes on bugs and flaws for each file.`;

    const coderOutput = await runGeminiWithRetry(prompt, '@heads_down_coder', batchSandbox, 5, REVIEW_MODEL, 300000);
    return `--- Coder Review Batch ${index} ---\n${coderOutput}`;
  });

  // 2. Lead Architect for full-diff review
  const architectPromise = (async () => {
    const archSandbox = await mkdtempSafe(path.join(sandboxDir, 'arch-'));
    const archDiffFile = path.join(archSandbox, 'full_diff.txt');
    await writeFileSafe(archDiffFile, fullContent);

    const prompt = `Review the full set of changes in "full_diff.txt" from a lead architect perspective. Focus on system integrity, architectural consistency, and cross-file dependencies.`;
    const archOutput = await runGeminiWithRetry(prompt, '@lead_architect', archSandbox, 5, REVIEW_MODEL, 300000);
    return `--- Architectural Review ---\n${archOutput}`;
  })();

  const workerNotesResults = await Promise.all([...fileWorkerPromises, architectPromise]);
  const activeNotes = workerNotesResults.filter((note) => note !== null);

  // Write manual audit reports to TARGET_DIR
  try {
    const coderNotes = activeNotes.filter((n) => n.startsWith('--- Coder Review Batch'));
    const archNotes = activeNotes.filter((n) => n.startsWith('--- Architectural Review ---'));

    if (coderNotes.length > 0) {
      writeFileSafe(path.join(targetDir, 'coder-report.md'), coderNotes.join('\n\n'));
      console.log(`::notice::✅ Coder audit report successfully written to target directory.`);
    }
    if (archNotes.length > 0) {
      writeFileSafe(path.join(targetDir, 'architect-report.md'), archNotes.join('\n\n'));
      console.log(`::notice::✅ Architect audit report successfully written to target directory.`);
    }
  } catch (err) {
    console.log(`::warning::Failed to write manual audit reports: ${err.message}`);
  }

  return activeNotes;
}

async function runReducePhase(workerNotes, outputFilePath) {
  console.log('::notice::[REDUCE] Synthesizing final review report');
  const aggregatedNotes = workerNotes.join('\n\n');
  const rawFindingsFile = path.join(sandboxDir, 'raw_findings.txt');
  writeFileSafe(rawFindingsFile, aggregatedNotes);

  const scientistPrompt = `Analyze and aggregate the raw worker review findings in "raw_findings.txt" inside your current directory.
In your final synthesized report, you must:
1. Explicitly check for and summarize findings on: security, coding standards, spelling/wording, and an automation audit.
2. Provide suggested commit details. You MUST use the exact headers "Commit Title:" and "Commit Message:" to introduce these fields so they can be programmatically verified.
3. Output an explicit approval status (such as "PR Review Status: 🟢 PERFECT" or "STATUS: APPROVED" if there are exactly 0 findings, or "STATUS: UNAPPROVED" if there are HIGH or MEDIUM severity findings).
4. If there are any findings of any severity, you MUST format them in a Markdown table with the columns: \`| Severity | File | Finding |\`.`;
  const scientistOutput = await runGeminiWithRetry(
    scientistPrompt,
    '@data_scientist',
    sandboxDir,
    5,
    REVIEW_MODEL,
    300000,
  );

  const report = scientistOutput;
  console.log('::notice::--- Final Review Report ---');
  report.split('\n').forEach((line) => console.log(`::notice::${line}`));

  // Save report to file if output path is specified
  if (outputFilePath) {
    try {
      writeFileSafe(outputFilePath, report);
      console.log(`::notice::✅ Final report successfully written to: ${outputFilePath}`);
    } catch (err) {
      console.log(`::error::❌ Failed to write report to ${outputFilePath}: ${err.message}`);
      // Don't exit on report save failure, as review sign-off is independent
    }
  }

  return report;
}

async function runReviewPipeline(reportContent, targetDir, workspaceRoot) {
  // Load project manager instructions
  const pmAgentPromptPath = path.join(workspaceRoot, '.gemini/agents/project_manager.md');
  const pmAgentPromptContent = await readFileSafe(pmAgentPromptPath);

  const prompt = `${pmAgentPromptContent}\n\n### RAW REVIEW REPORT:\n\n${reportContent}\n\nPlease generate an itemized worklist of tasks needed to reach a clean state. Output in markdown checklist format (e.g., "- [ ] task"). If the worklist is empty, output "APPROVED". DO NOT use any tools; simply output the markdown checklist content.`;

  console.log(`::notice::Invoking @project_manager to analyze review and generate remediation worklist...`);

  const pmOutput = await runGeminiWithRetry(prompt, '@project_manager', sandboxDir, 5, REVIEW_MODEL, 60000);

  // Save report to logs (reintroduced to satisfy saveReport requirement and log preservation)
  const LOGS_DIR = path.join(targetDir, 'logs');
  const reportFile = path.join(LOGS_DIR, `project_manager_report.md`);
  await writeFileSafe(reportFile, reportContent, { mode: 0o600 });

  return cleanMarkdownBlocks(pmOutput);
}

async function validateReport(report, targetDir) {
  // Recursive worklist loop
  const currentReport = report;
  const worklist = await runReviewPipeline(currentReport, targetDir, process.cwd());

  if (worklist.trim() === 'APPROVED' || worklist.trim() === '') {
    console.log('::notice::🟢 Review Approved by Project Manager.');
    return;
  }

  // Worklist exists, save to target directory and loop back to implementation
  const remediationChecklistPath = path.join(targetDir, 'remediation-report.md');
  try {
    await writeFileSafe(remediationChecklistPath, worklist);
    console.log(`::notice::✅ Remediation report successfully written to: ${remediationChecklistPath}`);
  } catch (err) {
    console.log(`::error::❌ Failed to write remediation report to ${remediationChecklistPath}: ${err.message}`);
  }

  console.log('::error::❌ Review Unapproved: Findings require remediation.');
  console.log(`::notice::💡 Worklist:\n${worklist}`);

  // Trigger feedback loop by failing the review gate
  await revokeReviewState(targetDir);
  process.exit(1);
}

async function writeSignatures(report, planHash, activeDiff, targetDir) {
  await revokeSignature(targetDir, 'review-approval.json');

  const diffHash = crypto.createHash('sha256').update(activeDiff).digest('hex');
  const commitMsgMatch = report.match(/Commit Message:\s*(["'`])(.*?)\1/i) || report.match(/Commit Message:\s*(.*)/i);
  const suggestedCommitMessage = commitMsgMatch ? (commitMsgMatch[2] ?? commitMsgMatch[1]).trim() : '';

  await writeFileSafe(
    path.join(targetDir, 'review-approval.json'),
    JSON.stringify(
      {
        status: 'approved',
        plan_hash: planHash,
        diff_hash: diffHash,
        suggested_commit_message: suggestedCommitMessage,
        timestamp: new Date().toISOString(),
      },
      null,
      2,
    ),
    { mode: 0o400 },
  );

  await setPhase(targetDir, 'commit');

  console.log('::notice::🟢 Gate 2 (Review) Cryptographically Signed successfully!');
}

function showHelp() {
  console.log(`Usage: code-review.js [path] [options]

Runs the Gemini Map-Reduce Code Review orchestrator on the current workspace or specified path.

Options:
  help, -h, --help           Show this help message

If a path is provided, it reviews that file or directory directly instead of using git diff.
`);
  process.exit(0);
}

async function main() {
  // Force process.cwd() to be the repository root if executed from within agent-scripts or tests folder
  const currentDirName = path.basename(process.cwd());
  if (currentDirName === 'agent-scripts') {
    process.chdir(path.resolve(__dirname, '..'));
  } else if (currentDirName === 'tests') {
    process.chdir(path.resolve(__dirname, '../..'));
  }

  const args = process.argv.slice(2);
  if (args.includes('help') || args.includes('-h') || args.includes('--help')) {
    showHelp();
  }

  const TARGET_DIR = await resolveTargetDir();

  // Check for incomplete remediation report
  const remediationReportPath = path.join(TARGET_DIR, 'remediation-report.md');
  if (fileExistsSafe(remediationReportPath)) {
    const remediationContent = await readFileSafe(remediationReportPath, 'utf-8');
    if (remediationContent && remediationContent.includes('- [ ]')) {
      console.log(
        `::error::❌ Review Blocked: An incomplete remediation checklist exists at ${remediationReportPath}. Please implement all remediation steps and check them off (change '- [ ]' to '- [x]') before running the review again.`,
      );
      process.exit(1);
    }
  }

  console.log('::notice::🔍 Starting Map-Reduce Review Orchestrator...');

  // Initialize unique temporary sandbox directory
  try {
    sandboxDir = await mkdtempSafe(path.join(os.tmpdir(), 'gemini-review-sandbox-'));
    console.log(`::notice::📦 Created secure subagent sandbox: ${sandboxDir}`);
    registerCleanupTraps(sandboxDir);
  } catch (err) {
    console.log('::error::❌ Failed to create temporary sandbox directory: ' + err.message);
    await revokeReviewState(TARGET_DIR);
    process.exit(1);
  }

  // 1. Verify Planning Gate
  const planHash = await verifyGates(TARGET_DIR);

  // 2. Run Pre-Review Tests
  await runTests(TARGET_DIR);

  // 3. Identify Files to Review (Single File Mode vs. Dir Mode vs. Git Diff Mode)
  const { outputFilePath, filteredFiles, activeDiff, isEntireFileReview } = await identifyFilesToReview(
    process.argv.slice(2),
    TARGET_DIR,
  );

  // 4. Map Phase: Invoke heads_down_coder in parallel for all files with staggered launch
  const workerNotes = await runMapPhase(filteredFiles, isEntireFileReview, TARGET_DIR);

  // 5. Reduce Phase: Invoke data_scientist to synthesize report
  const report = await runReducePhase(workerNotes, outputFilePath);

  // 6. Validation checks
  await validateReport(report, TARGET_DIR);

  // 7. Write approval signatures
  await writeSignatures(report, planHash, activeDiff, TARGET_DIR);
}

main().catch((err) => {
  console.log('::error::❌ Fatal Review Orchestrator Error: ' + (err.stack || err.message));
  process.exit(1);
});
