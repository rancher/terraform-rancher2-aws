import { verifyPlanGate, healApprovalState } from '../../../agent-scripts/tools/approval.js';
import { setLock, setPhase } from '../../../agent-scripts/tools/state.js';
import { allow, deny } from '../shared.js';

export async function clearPrePlanFlag(targetDir) {
  const hookName = 'clearPrePlanFlag';
  await setPhase(targetDir, 'plan');
  await setLock(targetDir, false);
  await healApprovalState(targetDir, 'all');

  allow(
    hookName,
    '✨ You have successfully entered Plan Phase. All tools are now unlocked for planning. 👉 ACTION REQUIRED: Draft your plan and then use `ask_user` to request approval.',
  );
}

export async function beforeExitPlanMode(inputData, targetDir) {
  // BeforeTool hook for exit_plan_mode
  const hookName = 'beforeExitPlanMode';
  const tool_name = 'exit_plan_mode';

  if (inputData.tool_name !== 'exit_plan_mode') {
    allow(hookName, inputData.tool_name, inputData.tool_input);
  }

  const planHash = await verifyPlanGate(targetDir);
  if (!planHash) {
    deny(
      'Gate 1 (Planning Gate) Exit',
      'You cannot exit Plan Mode until the user has cryptographically approved the plan.',
      'Present your plan file under plans/ to the user using the `ask_user` tool with intent = "plan approval" and plan = "markdown contents..." to obtain cryptographic plan approval. Only after the user approves will you be permitted to exit Plan Mode.',
    );
  }

  allow(hookName, tool_name, inputData.tool_input);
}

export async function afterExitPlanMode(inputData, targetDir) {
  // AfterTool hook for exit_plan_mode
  if (inputData.tool_name !== 'exit_plan_mode') {
    allow('afterExitPlanMode', inputData.tool_name);
  }

  await setPhase(targetDir, 'implement');

  allow(
    'afterExitPlanMode',
    '✅ Exited Plan Mode. Implementation phase successfully unlocked! 👉 ACTION REQUIRED: Proceed immediately to Implement your plan, then move to the Review Phase by running the code-review.js script.',
  );
}
