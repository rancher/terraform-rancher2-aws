import TOML from '@iarna/toml';
import { execSync } from 'child_process';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { readState } from '../../agent-scripts/tools/state.js';

export function deny(phaseName, reason, nextSteps) {
  const fullDetails =
    `❌ ${phaseName} Failure!\n\n` +
    `👉 REASON: ${reason}\n\n` +
    `👉 WHAT TO DO NEXT:\n${nextSteps}\n\n` +
    `For the exact schema, templates, and proper formatting, please refer to the documentation: docs/development/reference/AskUserComponent.md`;

  console.log(
    JSON.stringify({
      decision: 'deny',
      reason: fullDetails,
      systemMessage: `🔒 Security Block: ${phaseName} validation failed.\n\n${fullDetails}`,
    }),
  );
  process.exit(0);
}

export function allow(hookName, tool_name, tool_input = null, prependInput = '', appendInput = '') {
  const payload = {
    decision: 'allow',
    systemMessage: `${hookName} approves ${tool_name}\n\n`,
  };

  if (tool_input && typeof tool_input === 'object') {
    const modifiedInput = JSON.parse(JSON.stringify(tool_input));

    if (prependInput || appendInput) {
      if (modifiedInput.questions && Array.isArray(modifiedInput.questions) && modifiedInput.questions[0]) {
        if (prependInput) {
          modifiedInput.questions[0].question = prependInput + modifiedInput.questions[0].question;
        }
        if (appendInput) {
          modifiedInput.questions[0].question = modifiedInput.questions[0].question + appendInput;
        }
      } else if (modifiedInput.question !== void 0) {
        if (prependInput) {
          modifiedInput.question = prependInput + modifiedInput.question;
        }
        if (appendInput) {
          modifiedInput.question = modifiedInput.question + appendInput;
        }
      } else if (modifiedInput.prompt !== void 0) {
        if (prependInput) {
          modifiedInput.prompt = prependInput + modifiedInput.prompt;
        }
        if (appendInput) {
          modifiedInput.prompt = modifiedInput.prompt + appendInput;
        }
      } else {
        modifiedInput.question = (prependInput || '') + (appendInput || '');
      }
    }

    payload.tool_input = modifiedInput;
  } else if (tool_input) {
    payload.tool_input = tool_input;
  }

  console.log(JSON.stringify(payload, null, 2));
  process.exit(0);
}

export async function getPhase(targetDir) {
  const state = await readState(targetDir);
  if (state) {
    return { success: true, data: state.currentPhase };
  }
  return { success: false, error: 'phase-state.json not found' };
}

function getAskUserPromptText(tool_input) {
  if (!tool_input) {
    return '';
  }
  let promptText = '';
  if (tool_input.questions && Array.isArray(tool_input.questions) && tool_input.questions.length > 0) {
    promptText = tool_input.questions[0].question || '';
  } else if (tool_input.question) {
    promptText = tool_input.question;
  } else if (tool_input.prompt) {
    promptText = tool_input.prompt;
  }
  return promptText ? promptText.trim() : '';
}

function parseToml(promptText) {
  try {
    const data = TOML.parse(promptText);
    return { success: true, data: data };
  } catch (err) {
    return { success: false, error: err.message };
  }
}

export function getTomlFrom(tool_input) {
  const promptText = getAskUserPromptText(tool_input);
  const tomlResult = parseToml(promptText);
  const tomlData = tomlResult.success ? tomlResult.data : null;
  return tomlData;
}

export function validateAskUser(hook_name, tool_name, tool_input) {
  if (tool_name !== 'ask_user') {
    allow(`${hook_name}`, 'not an ask_user tool call');
  }

  if (!tool_input) {
    deny(
      `${hook_name}`,
      'The ask_user tool call was invoked without a tool_input value',
      'Try again making sure to provide some value to the tool call.',
    );
  }

  const promptText = getAskUserPromptText(tool_input);
  if (!promptText) {
    deny(
      `${hook_name}`,
      'The ask_user tool call was invoked without any question text/prompt.',
      "Ensure that the first element in 'questions' contains a non-empty 'question' string, or supply a 'question' or 'prompt' parameter.",
    );
  }

  // Parse TOML
  const tomlResult = parseToml(promptText);
  if (!tomlResult.success) {
    deny(
      `${hook_name}`,
      `Failed to parse prompt as valid TOML. Error: ${tomlResult.error}`,
      'Format your prompt string exactly as a valid TOML document. Ensure that all strings are correctly closed, and wrap multi-line strings (such as plans) using triple-quotes (""").',
    );
  }

  const tomlData = tomlResult.data;

  // Validate generic fields
  if (!tomlData.intent || typeof tomlData.intent !== 'string') {
    deny(
      `${hook_name}`,
      "The TOML payload is missing the required 'intent' string field.",
      'Add an \'intent\' field as a string indicating the purpose of the call (e.g., intent = "plan approval" or intent = "clarification").',
    );
  }

  const allowedIntents = [
    'plan approval',
    'commit approval',
    'clarification',
    'suggest action',
    'question',
    'feedback',
  ];

  const normalizedIntent = tomlData.intent.trim().toLowerCase();
  if (!allowedIntents.includes(normalizedIntent)) {
    deny(
      `${hook_name}`,
      `The TOML payload has an unrecognized 'intent': "${tomlData.intent}".`,
      `Please set a valid intent from the following list:\n` +
        allowedIntents.map((i) => `  - "${i}"`).join('\n') +
        `\n\n` +
        `Choose the intent that best matches your task (e.g., 'plan approval' for planning, 'clarification' or 'question' for general queries).`,
    );
  }

  if (!tomlData.request || typeof tomlData.request !== 'string') {
    deny(
      `${hook_name}`,
      "The TOML payload is missing the required 'request' string field.",
      "Add a 'request' field as a string containing the actual question, prompt, or approval request directed to the human developer.",
    );
  }

  // Enforce yesno type for approval gates to avoid response guesswork
  if (normalizedIntent === 'plan approval' || normalizedIntent === 'commit approval') {
    const questions = tool_input && tool_input.questions;
    const type = questions && questions[0] ? questions[0].type : tool_input && tool_input.type;
    if (type !== 'yesno') {
      deny(
        `${hook_name}`,
        `The ask_user tool question type is set to "${type || 'undefined'}", but for "${tomlData.intent}" intent we strictly require type = "yesno".`,
        'Configure your ask_user tool call to use type = "yesno" so that the user is presented with a standard Yes/No confirmation prompt.',
      );
    }
  }
}

/**
 * Main execution function.
 */
export function parseToolResponse(tool_response) {
  try {
    const normalizedResponse = normalizeToolResponse(tool_response);
    return extractAnswerText(normalizedResponse);
  } catch (err) {
    console.error(`🔒 Hook Info: Failed to parse tool response in askUserPlanProof: ${err.message}`);
    return tool_response ? tool_response.llmContent || JSON.stringify(tool_response) : '';
  }
}

/**
 * Safely attempts to parse a JSON string.
 * Returns the parsed object on success, or the original value on failure.
 */
function safeParseJSON(value) {
  if (typeof value !== 'string') {
    return value;
  }
  try {
    return JSON.parse(value);
  } catch (err) {
    if (err && err.message && !err.message.includes('Unexpected token')) {
      console.warn('🔒 Hook Warning: JSON parse failed:', err.message);
    }
    return value;
  }
}

/**
 * Safely extracts the first value from an object.
 */
function getFirstValue(obj) {
  if (!obj || typeof obj !== 'object') {
    return '';
  }
  return Object.values(obj)[0] || '';
}

/**
 * Normalizes the tool response by unpacking it from strings or 'output' wrappers.
 */
function normalizeToolResponse(response) {
  let res = safeParseJSON(response);

  // If the response is wrapped in an 'output' property, try to unpack it
  if (res && res.output !== void 0) {
    if (typeof res.output === 'string') {
      const parsedOutput = safeParseJSON(res.output);
      if (parsedOutput && typeof parsedOutput === 'object') {
        res = parsedOutput;
      } else {
        res = res.output;
      }
    } else if (typeof res.output === 'object') {
      res = res.output;
    }
  }

  return res;
}

/**
 * Traverses a normalized response object to find the most relevant answer text.
 */
function extractAnswerText(res) {
  if (!res || typeof res !== 'object') {
    return '';
  }

  // Priority 1: Direct 'answers' object
  if (res.answers) {
    return getFirstValue(res.answers);
  }

  // Priority 2: Nested 'llmContent' payload
  if (res.llmContent) {
    const parsedLlm = safeParseJSON(res.llmContent);

    if (parsedLlm && typeof parsedLlm === 'object') {
      return parsedLlm.answers ? getFirstValue(parsedLlm.answers) : getFirstValue(parsedLlm);
    }

    // Fallback if llmContent is just a raw string
    return res.llmContent || '';
  }

  // Priority 3: Fallback to the first value of the raw object
  return getFirstValue(res);
}

export function hasValidSigningKey() {
  const homeDir = os.homedir();
  const sshPubKeyFile = path.resolve(homeDir, '.gemini/ssh-key.pub');

  // Fail fast if the SSH agent is not running
  if (!process.env.SSH_AUTH_SOCK) {
    return false;
  }

  // Verify the SSH agent is responsive (bypass in test environments using the mock socket)
  const isTestBypass =
    process.env.NODE_ENV === 'test' && process.env.SSH_AUTH_SOCK === '/tmp/gemini-mock-ssh-agent.sock';
  if (!isTestBypass) {
    try {
      execSync('ssh-add -l', { stdio: 'ignore' });
    } catch (err) {
      // ssh-add -l returns 1 if agent is running but empty. It returns 2 on connection error.
      if (err.status === 2) {
        return false;
      }
    }
  }

  try {
    // Verify the public key is readable
    fs.accessSync(sshPubKeyFile, fs.constants.R_OK);
    return true;
  } catch (err) {
    // Retaining debug logs for permission or unexpected errors
    if (err.code === 'EACCES' || err.code === 'EPERM') {
      console.error('🔒 Hook Debug: Permission denied! Please check read permissions for the public key.');
    } else if (err.code !== 'ENOENT') {
      console.error(`🔒 Hook Debug: Error checking public key: ${err.message}`);
    }

    return false;
  }
}
