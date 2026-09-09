import os from 'os';
import path from 'path';
import { findLatestActivePlan, validatePlanContent } from '../../../agent-scripts/tools/plan.js';
import { handlePlanApproval } from '../../../agent-scripts/tools/approval.js';
import {
  allow,
  deny,
  getPhase,
  getTomlFrom,
  hasValidSigningKey,
  parseToolResponse,
  validateAskUser,
} from '../shared.js';

async function inPlanPhase(targetDir) {
  const phaseResult = await getPhase(targetDir);
  return phaseResult && phaseResult.success && phaseResult.data === 'plan';
}

export async function beforeAskUserPlan(inputData, targetDir) {
  const { tool_name, tool_input } = inputData;
  const hookName = 'beforeAskUserPlan';

  validateAskUser(hookName, tool_name, tool_input);

  const tomlData = getTomlFrom(tool_input);
  const intent = tomlData.intent.trim().toLowerCase();

  // If the agent is trying to request plan approval but we aren't in the plan phase, explicitly deny and guide them
  if (intent === 'plan approval' && !(await inPlanPhase(targetDir))) {
    const phaseRes = await getPhase(targetDir);
    const currentPhase = phaseRes && phaseRes.success ? phaseRes.data : 'unknown';
    const statePath = path.join(targetDir, 'phase-state.json');
    deny(
      'Gate 1 (Planning Gate) Phase Validation',
      `You are attempting to request plan approval, but the workspace is currently in the "${currentPhase}" phase.`,
      "To request plan approval, the workspace must be in the 'plan' phase.\n" +
        `If you need to re-verify or change your plan, you must reset the phase state file at ${statePath} to:\n` +
        '{\n  "currentPhase": "plan"\n}\n' +
        'Once you reset the phase-state file, re-run the `ask_user` tool with intent = "plan approval".',
    );
  }

  // If we are in another phase and asking standard questions, pass through safely
  if (!(await inPlanPhase(targetDir))) {
    allow(hookName, tool_name);
  }

  if (Object.prototype.hasOwnProperty.call(tomlData, 'plan') && intent !== 'plan approval') {
    deny(
      'Gate 1 (Planning Gate) Intent Validation',
      `The TOML payload contains a 'plan' field, but the intent is set to "${tomlData.intent}".`,
      'To request planning approval, you must set intent = "plan approval" in your TOML payload.',
    );
  }

  if (intent !== 'plan approval') {
    allow(hookName, tool_name);
  }

  // Validate specific fields
  if (!tomlData.plan || typeof tomlData.plan !== 'string') {
    deny(
      'Gate 1 (Planning Gate) Schema Validation',
      "For plan approval intent, the string 'plan' field containing the markdown plan is required.",
      'Include the \'plan\' field in your TOML, populated with the complete markdown plan content. Use triple-quotes (""") for the multiline plan string.',
    );
  }

  // Verify the plan is valid before allowing ask_user to prompt the user
  const activePlan = findLatestActivePlan(targetDir);
  if (!activePlan) {
    deny(
      'Gate 1 (Planning Gate) Pipeline Verification',
      'Active plan file not found in session directory!',
      'Please write your plan file as a markdown document under plans/ first before calling `ask_user` with the intent to validate.',
    );
  }

  const validation = validatePlanContent(activePlan);
  if (!validation.valid) {
    const errorsList = validation.errors.map((err) => `  - ${err}`).join('\n');
    deny(
      'Gate 1 (Planning Gate) Schema Validation',
      'The proposed plan has invalid structure and violates repository standards:\n' + errorsList,
      `You must rewrite the plan file at:\n   ${activePlan}\nto satisfy all repository requirements (include markdown checklist - [ ], comprehensive tests, quality gates, agentic framework maintenance, and documentation updates) before you can ask the user for approval.`,
    );
  }

  // all filters passed, allowing tool use
  allow(hookName, tool_name);
}

export async function afterAskUserPlan(inputData, targetDir) {
  const { tool_name, tool_input, tool_response } = inputData;
  const hookName = 'afterAskUserPlan';

  validateAskUser(hookName, tool_name, tool_input);
  const tomlData = getTomlFrom(tool_input);

  const intent = tomlData.intent.trim().toLowerCase();

  // If the agent is trying to approve plan but we aren't in the plan phase, explicitly deny and guide them
  if (intent === 'plan approval' && !(await inPlanPhase(targetDir))) {
    const phaseRes = await getPhase(targetDir);
    const currentPhase = phaseRes && phaseRes.success ? phaseRes.data : 'unknown';
    deny(
      'Gate 1 (Planning Gate) Phase Validation',
      `You are attempting to approve the plan, but the workspace is currently in the "${currentPhase}" phase.`,
      "To approve the plan, the workspace must be in the 'plan' phase. Reset phase-state.json to 'plan' first.",
    );
  }

  if (intent !== 'plan approval') {
    allow(hookName, tool_name);
  }

  // Use the robust response parser from shared.js
  const answerText = parseToolResponse(tool_response);
  const isApproved =
    String(answerText || '')
      .trim()
      .toLowerCase() === 'yes';

  if (!isApproved) {
    deny(
      hookName,
      "User did not approve plan, they must select the 'yes' response.",
      "Ask the user what they would like to change or inform them that they must choose the 'Yes' option when asked to validate the plan and try again.",
    );
  }

  if (!hasValidSigningKey()) {
    deny(
      'Gate 1 (Planning Gate) Cryptographic Setup',
      'SSH key signing is not configured properly or your SSH agent is offline.',
      'To fail-forward and fix this instantly, run the following troubleshooting commands in your local shell:\n\n' +
        '  eval "$(ssh-agent -s)"\n' +
        '  ssh-add ~/.gemini/ssh-key\n\n' +
        'For detailed setup guidance, please see the developer setup documentation: docs/development/tutorials/GettingStarted.md',
    );
  }

  const homeDir = os.homedir();
  const sshPubKeyFile = path.resolve(homeDir, '.gemini/ssh-key.pub');
  const planContent = tomlData.plan;
  const result = handlePlanApproval(targetDir, sshPubKeyFile, planContent);

  allow(hookName, tool_name, tool_input, '', '\n\n' + result.systemMessage + ' You may now call exit_plan_mode.');
}
