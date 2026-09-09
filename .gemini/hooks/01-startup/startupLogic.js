import fs from 'fs';
import path from 'path';
import { readFileSafe } from '../../../agent-scripts/tools/file.js';
import { gitRevParseShowToplevel } from '../../../agent-scripts/tools/git.js';
import { initializeState } from '../../../agent-scripts/tools/state.js';
import { deny } from '../shared.js';

/**
 * Consumes and discards hook input from stdin to prevent broken pipes.
 */
export function discardStdin() {
  try {
    fs.readFileSync(0, 'utf-8');
  } catch (err) {
    console.error(`🔒 Hook Warning: Failed to read from stdin: ${err.message || err}`);
  }
}

/**
 * Verifies if the session is running inside a secure, hermetic Nix shell.
 * Returns an object containing the markdown description and active status.
 */
export function verifyNixEnvironment() {
  const inNixShell = !!process.env.IN_NIX_SHELL;
  const text = inNixShell
    ? '✅ NIX ENVIRONMENT: Session is securely running inside a hermetic Nix shell.\n\n'
    : '⚠️ NIX ENVIRONMENT WARNING: Session is NOT running inside a Nix shell. Standard dependencies may be missing. Advise the developer to run `nix develop`.\n\n';

  if (inNixShell) {
    console.error('Nix shell environment verified.');
  } else {
    console.error('Warning: Not running in a Nix shell.');
  }

  return { text, active: inNixShell };
}

/**
 * Loads the standing Agentic Framework architectural specification document.
 */
export async function loadFrameworkContext() {
  const frameworkDocPath = 'docs/development/AgenticFramework.md';
  let context = '';

  const frameworkDoc = await readFileSafe(frameworkDocPath);
  if (frameworkDoc) {
    context += '# Context from docs/development/AgenticFramework.md\n\n';
    context += frameworkDoc;
    context += '\n\n';
    console.error(`Loaded ${frameworkDocPath}`);
  } else {
    console.error(`Warning: ${frameworkDocPath} not found`);
  }

  return context;
}

/**
 * Enforces Plan Mode entry on startup by setting up plan-mode flag files
 * and initializing the central phase state machine (FAIL-FAST).
 */
export async function initializeWorkspaceFlags(targetDir) {
  try {
    await initializeState(targetDir);
    console.error('phase-state.json initialized successfully to plan.');
  } catch (err) {
    deny(
      'Startup Phase State Initialization',
      `Failed to initialize or write the session phase-state.json file. Error: ${err.message}`,
      'Ensure that the workspace temporary directory is fully writeable, that permissions are correct, and that no other process is holding a write lock on phase-state.json.',
    );
  }
}

/**
 * Locks the .aiexclude and .claudeignore files to read-only mode to prevent agent tampering (NON-CRITICAL).
 */
export async function protectExcludeFiles() {
  try {
    let repoRoot = process.cwd();
    try {
      repoRoot = await gitRevParseShowToplevel();
    } catch (err) {
      console.error(`🔒 Hook Warning: Failed to determine git repo root: ${err.message}`);
    }

    const excludeFiles = ['.aiexclude', '.claudeignore'];
    for (const file of excludeFiles) {
      const filePath = path.join(repoRoot, file);
      if (fs.existsSync(filePath)) {
        fs.chmodSync(filePath, 0o400);
      }
    }
  } catch (err) {
    console.error(
      `🔒 Hook Warning: Failed to set read-only permissions on exclude files. Error: ${err.message || err}`,
    );
  }
}

/**
 * Combines critical mandates, Nix status, and framework documentation into a single markdown context block.
 */
export function buildCombinedContext(nixText, frameworkContext) {
  const mandateHeader = `###############################################################################
#                           CRITICAL AGENT MANDATES                                 #
#                                                                                   #
# 1. YOU MUST FOLLOW THE DEVELOPMENT PROCESS IN 'docs/development/how-to/DevelopmentProcess.md'. #
# 2. YOU ARE STRICTLY FORBIDDEN FROM EXECUTING ANY COMMIT OR PUSH COMMANDS.         #
#    COMMITS AND PUSHES ARE SOLELY MANAGED OUT-OF-BAND BY SYSTEM HOOKS.             #
# 3. SOURCE EDITS ARE BLOCKED UNTIL PLAN APPROVAL IS GRANTED.                       #
#    ALL ACTIVE TASK CHECKLISTS RESIDE STRICTLY INSIDE THE PLAN.                    #
# 4. WE ENFORCE A GATED 4-PHASE LIFECYCLE (Plan, Implement, Review, Commit).        #
#    YOU MUST TRANSITION THROUGH THESE PHASES SEQUENTIALLY WITHOUT SKIPPING.        #
#    UPON COMPLETING A PHASE, IMMEDIATELY PROCEED TO THE NEXT.                      #
#                                                                                   #
# FAILURE TO COMPLY WILL TRIGGER SECURITY BLOCKS AND PROCESS TERMINATION.           #
#                                                                                   #
# DEVELOPMENT PHILOSOPHY:                                                           #
# We prefer explicit composition over complex inheritance or prototype hacks.        #
# NEVER swallow errors or use empty catch blocks in any hook or application files.   #
# Every caught exception must be explicitly logged or safely handled.                 #
###############################################################################\n\n`;

  const mandateFooter = `###############################################################################
#                           IMMEDIATE ACTION REQUIRED                               #
#                                                                                   #
# You must immediately enter PLAN MODE as your first action in this session.        #
# Evaluate the user's initial request and draft a step-by-step imperative plan.     #
#                                                                                   #
# PLAN FORMAT REQUIREMENTS:                                                         #
# Your plan MUST include a markdown checklist (using "- [ ]") that covers:          #
# 1. The specific implementation tasks.                                             #
# 2. Running comprehensive tests and linters.                                       #
# 3. Maintaining the agentic framework if improvements or bugs are found.           #
# 4. Enforcing standard quality gates.                                              #
# 5. Updating documentation to describe the changes.                                #
#                                                                                   #
# MAP-REDUCE REVIEW PIPELINE INSTRUCTIONS:                                          #
# Run the local code-review.js agent script to initiate the automated Map-Reduce    #
# review pipeline, which executes tests, audits, and obtains Gate 2 signatures.     #
###############################################################################\n`;

  const actionPrompt = `\n👉 ACTION REQUIRED: You must call the \`enter_plan_mode\` tool to formally enter the Plan Phase before utilizing other tools or modifying code.\n`;

  return mandateHeader + nixText + frameworkContext + mandateFooter + actionPrompt;
}

/**
 * Outputs the clean JSON structure with the combined context to stdout and exits cleanly.
 */
export function buildStartupOutput(combinedContext, inNixShell) {
  const output = {
    hookSpecificOutput: {
      additionalContext: combinedContext,
    },
    systemMessage: `✨ Workspace context injected. ${
      inNixShell ? '[Nix Shell: Active]' : '[Nix Shell: Inactive]'
    } 👉 ACTION REQUIRED: Enter Plan Mode`,
  };

  console.log(JSON.stringify(output, null, 2));
  process.exit(0);
}
