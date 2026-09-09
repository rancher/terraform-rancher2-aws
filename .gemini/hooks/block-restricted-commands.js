#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { verifySafeGitCommand, cleanCommandString } from '../../agent-scripts/tools/git.js';

const hookName = path.basename(process.argv[1]);
const isStartup = hookName === '01-startup-context.js';
const introLog = `🔒 Hook: ${hookName} - ${isStartup ? 'Loading startup context...' : 'Loading hook context...'}`;
console.error(introLog);

const originalLog = console.log;
let hasLogged = false;

console.log = function (msg) {
  if (hasLogged) {
    return;
  }
  try {
    const parsed = JSON.parse(msg);
    if (parsed.systemMessage) {
      console.error(parsed.systemMessage);
    }
    const exitLog = `🔒 Hook: ${hookName} - ${isStartup ? 'context successfully loaded.' : 'Hook successfully loaded.'}`;
    console.error(exitLog);

    const msgs = [introLog];
    if (parsed.systemMessage) {
      msgs.push(parsed.systemMessage);
    }
    msgs.push(exitLog);
    parsed.systemMessage = msgs.join('\n');

    if (!parsed.decision && !isStartup) {
      parsed.decision = 'allow';
    }

    originalLog(JSON.stringify(parsed, null, 2));
    hasLogged = true;
  } catch (err) {
    console.error(err.message || err);
    originalLog(msg);
  }
};

process.on('exit', (code) => {
  if (!hasLogged) {
    const exitMsg = `🔒 Hook Error (${hookName}): Silent early exit detected with code ${code}.`;
    console.error(exitMsg);
    process.stdout.write(
      JSON.stringify({
        decision: 'deny',
        systemMessage: `${introLog}\n${exitMsg}`,
      }) + '\n',
    );
    hasLogged = true;
  }
});

process.on('uncaughtException', (err) => {
  const errMsg = `🔒 Hook Error (${hookName}): Unhandled exception - ${err.message || err}`;
  console.error(errMsg);
  if (!hasLogged) {
    process.stdout.write(
      JSON.stringify({
        decision: 'deny',
        systemMessage: `${introLog}\n${errMsg}`,
      }) + '\n',
    );
    hasLogged = true;
  }
  process.exit(1);
});

process.on('unhandledRejection', (reason) => {
  const errMsg = `🔒 Hook Error (${hookName}): Unhandled promise rejection - ${reason.message || reason}`;
  console.error(errMsg);
  if (!hasLogged) {
    process.stdout.write(
      JSON.stringify({
        decision: 'deny',
        systemMessage: `${introLog}\n${errMsg}`,
      }) + '\n',
    );
    hasLogged = true;
  }
  process.exit(1);
});

async function main() {
  let inputData;
  try {
    inputData = JSON.parse(fs.readFileSync(0, 'utf-8'));
  } catch (err) {
    console.error('Failed to parse stdin JSON in block-restricted-commands:', err.message || err);
    console.log(
      JSON.stringify({
        decision: 'allow',
        systemMessage: '🔒 Hook Notification: Failed to parse input, allowing execution by default.',
      }),
    );
    process.exit(0);
  }

  async function verifyShellCommand(command, cwd) {
    let cmdStr = '';
    if (typeof command === 'string') {
      cmdStr = command;
    } else if (Array.isArray(command)) {
      cmdStr = command.join(' ');
    } else if (command && typeof command === 'object') {
      cmdStr = command.command || '';
    }
    const trimmedCmd = cmdStr.trim();

    // Strip leading env var assignments and optional sudo via cleanCommandString helper (SRP compliant)
    const commandClean = cleanCommandString(trimmedCmd);

    // Parse the agent scripts whitelist from agent-scripts/whitelist.json
    let isWhitelisted = false;
    if (trimmedCmd.includes('agent-scripts/')) {
      const whitelistFile = path.resolve(cwd || process.cwd(), 'agent-scripts/whitelist.json');
      if (fs.existsSync(whitelistFile)) {
        let whitelistContent = {};
        try {
          whitelistContent = JSON.parse(fs.readFileSync(whitelistFile, 'utf-8'));
        } catch (err) {
          console.error(`🔒 Warning: Failed to parse agent scripts whitelist.json: ${err.message}. Falling back.`);
        }
        const allowed = whitelistContent.allowed_scripts || [];
        // Ensure secure token boundaries to prevent spoofing, path traversal, or execution spoofs
        isWhitelisted = allowed.some((script) => {
          const escapedScript = script.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&');
          const regex = new RegExp(`(^|\\s|&&|\\|\\||;)${escapedScript}(\\s|$)`);
          return regex.test(trimmedCmd);
        });
      }
    }

    // Anti-Bypass Guardrail: Prevent spoofing the GEMINI_TEST environment variable
    if (/\bGEMINI_TEST\s*=/.test(trimmedCmd)) {
      return {
        decision: 'deny',
        reason:
          'Security Policy Violation: Spoofing the GEMINI_TEST environment variable is strictly prohibited.\n\n' +
          'This environment variable is reserved for internal pipeline tests and cannot be used to bypass mandatory project test gates.',
        systemMessage: '🔒 Security Block: Bypassing tests via GEMINI_TEST is prohibited.',
      };
    }

    // Anti-Bypass Guardrail: Unconditionally deny any manual writing, editing, or spoofing of any gate approval/challenge JSON/age files
    const isManipulatingApproval =
      /\b(echo|cat|touch|rm|mv|cp|write|tee|vim|vi|nano|printf|sed|awk)\b.*\b(plan-approval|test-approval|review-approval|user-approval)\.(json|challenge|age|sig)\b|>>?[^>]*\b(plan-approval|test-approval|review-approval|user-approval)\.(json|challenge|age|sig)\b/.test(
        commandClean,
      );
    if (isManipulatingApproval) {
      return {
        decision: 'deny',
        reason:
          'Security Policy Violation: Manually writing, editing, or spoofing any planning, testing, review, or commit gate approval files is strictly prohibited.\n\n' +
          'Gating approval files must ONLY be generated automatically and securely by our pipeline hooks and sub-agents.\n\n' +
          '👉 TO PROCEED:\n' +
          '1. Comply strictly with our gated sequence (Plan -> Test -> Review -> Commit).\n' +
          '2. For Plan Approval, use the `ask_user` tool with intent = "plan approval" and include the `plan` field in your TOML.\n' +
          '3. For Commit Approval, use the `ask_user` tool with intent = "commit approval" and include the `hash`, `commit-message`, and `pr-description` fields in your TOML.',
        systemMessage: '🔒 Security Block: Direct manipulation of approval files is prohibited.',
      };
    }

    // Anti-Bypass Guardrail: Unconditionally deny any manual deletion, renaming, or tampering with remediation-report.md
    const isManipulatingRemediation = /\b(rm|mv|cp|rename)\b.*\b(remediation-report)\.md\b/.test(commandClean);
    if (isManipulatingRemediation) {
      return {
        decision: 'deny',
        reason:
          '🔒 Security Policy Violation: Manually deleting, moving, or tampering with remediation-report.md is strictly prohibited.\n\n' +
          'The remediation checklist must only be written and updated automatically by the Gemini CLI review pipeline, and completed tasks must be checked off in-place (- [x]).',
        systemMessage: '🔒 Security Block: Deleting or tampering with remediation-report.md is prohibited.',
      };
    }

    // Protect the whitelist.json from any manual user write, edit, rename, move, delete, or spoofing operations
    const isManipulatingWhitelist =
      /\b(echo|cat|touch|rm|mv|cp|write|tee|vim|vi|nano|printf|sed|awk)\b.*\b(whitelist)\.json\b|>>?[^>]*\b(whitelist)\.json\b/.test(
        commandClean,
      );
    if (isManipulatingWhitelist) {
      return {
        decision: 'deny',
        reason:
          '🔒 Security Policy Violation: Manually writing, editing, or spoofing gating approvals or system whitelists is strictly prohibited.\n\n' +
          'These secure configuration files must ONLY be generated automatically and securely by our pipeline hooks and repository managers.\n\n' +
          '👉 TO PROCEED:\n' +
          '1. Comply strictly with our gated sequence (Plan -> Test -> Review -> Commit).\n' +
          '2. Do not attempt to modify secure system config files or signatures.',
        systemMessage: '🔒 Security Block: Direct manipulation of secure config files is prohibited.',
      };
    }

    // Anti-Bypass Guardrail: Unconditionally deny any manual execution of enforcer hook scripts inside .gemini/hooks/ or .claude/hooks/
    const isExecutingHooksManually =
      trimmedCmd.includes('.gemini/hooks/') ||
      trimmedCmd.includes('.gemini/hooks') ||
      trimmedCmd.includes('.claude/hooks/') ||
      trimmedCmd.includes('.claude/hooks') ||
      trimmedCmd.includes('agent-scripts/');
    const isGitDiff = commandClean.trim().startsWith('git diff');
    if (isExecutingHooksManually && !isGitDiff && !isWhitelisted) {
      return {
        decision: 'deny',
        reason:
          '🔒 Security Policy Violation: Manual execution of enforcer hook or agent scripts is strictly prohibited.\n\n' +
          'These scripts are part of the secure system pipeline and must only be executed automatically by the Gemini CLI lifecycle.\n\n' +
          '👉 TO PROCEED:\n' +
          'Do not try to run or trigger hook scripts manually. Instead, use the correct lifecycle tools:\n' +
          '1. For Plan Approval, call the `ask_user` tool with intent = "plan approval" containing your TOML payload.\n' +
          '2. To run reviews, run: agent-scripts/code-review.js \n' +
          '3. For Commit Approval, call the `ask_user` tool with intent = "commit approval" containing your TOML payload.\n',
        systemMessage: '🔒 Security Block: Manual execution of secure scripts is prohibited.',
      };
    }

    // Hand off Git specific checks to git.js
    return await verifySafeGitCommand(commandClean, cwd);
  }

  const { tool_name, tool_input, cwd } = inputData;

  if (tool_name === 'run_shell_command' && tool_input && tool_input.command) {
    const result = await verifyShellCommand(tool_input.command, cwd || process.cwd());
    if (result && result.decision === 'deny') {
      console.log(
        JSON.stringify({
          decision: 'deny',
          reason: result.reason || 'Command execution blocked by security policy.',
          systemMessage: '🔒 Security Block: Restricted shell command denied.',
        }),
      );
      process.exit(0);
    }
  }

  const fileModificationTools = ['write_file', 'replace', 'edit_file', 'create_file'];
  if (fileModificationTools.includes(tool_name) && tool_input) {
    const targetPath = tool_input.file_path || tool_input.path || '';
    if (targetPath.endsWith('eslint.config.mjs')) {
      console.log(
        JSON.stringify({
          decision: 'deny',
          reason:
            'Direct modification of eslint.config.mjs is restricted. If you need to change linting rules, you must use the ask_user tool to present the proposed changes and request that the developer apply them manually.',
          systemMessage: '🔒 Security Block: Modifying ESLint configuration is denied.',
        }),
      );
      process.exit(0);
    }
  }

  let allowedMessage = 'execution allowed.';
  if (tool_name === 'run_shell_command' && tool_input && tool_input.command) {
    const cmdStr = tool_input.command.length > 100 ? tool_input.command.substring(0, 97) + '...' : tool_input.command;
    allowedMessage = `\`${cmdStr}\` command execution allowed.`;
  } else if (tool_name) {
    allowedMessage = `\`${tool_name}\` execution allowed.`;
  }

  console.log(JSON.stringify({ decision: 'allow', systemMessage: `🔒 Hook Notification: ${allowedMessage}` }));
  process.exit(0);
}

main().catch((err) => {
  console.error('::error::Fatal Block Restricted Commands Hook Error:', err.stack || err.message);
  process.exit(1);
});
