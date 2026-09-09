import crypto from 'crypto';
import path from 'path';
import process from 'process';
import { verifyPlanGate, verifyReviewGate, healApprovalState } from './approval.js';
import { readFileSafe, writeFileSafe } from './file.js';
import {
  gitBranchList,
  gitBranchShowCurrent,
  gitCheckoutNewBranch,
  gitDiff,
  gitStatusPorcelain,
  gitSwitch,
} from './git.js';
import { findLatestActivePlan, validatePlanContent } from './plan.js';

export const PHASE_CONFIG = {
  plan: { locked: true, keyTool: 'enter_plan_mode' },
  implement: { locked: false, keyTool: '' },
  review: { locked: false, keyTool: '' },
  commit: { locked: true, keyTool: 'ask_user' },
};

export function getStatePath(targetDir) {
  return path.join(targetDir, 'phase-state.json');
}

export async function readState(targetDir) {
  const statePath = getStatePath(targetDir);
  const data = await readFileSafe(statePath);
  if (data) {
    try {
      return JSON.parse(data);
    } catch (err) {
      console.error(`Failed to parse phase-state.json: ${err.message}`);
    }
  }
  return null;
}

export async function writeState(targetDir, state) {
  const statePath = getStatePath(targetDir);
  await writeFileSafe(statePath, JSON.stringify(state, null, 2));
}

export async function initializeState(targetDir) {
  const state = {
    currentPhase: 'plan',
    locked: PHASE_CONFIG.plan.locked,
    keyTool: PHASE_CONFIG.plan.keyTool,
  };
  await writeState(targetDir, state);
  return state;
}

function calculateSha256(data) {
  return crypto.createHash('sha256').update(data).digest('hex');
}

// OCP Polymorphic Phase Transition Strategies Map
const TRANSITION_STRATEGIES = {
  plan: {
    canEnter: async () => true,
    onEnter: async () => {},
  },
  implement: {
    canEnter: async (targetDir, cwd) => {
      const planHash = await verifyPlanGate(targetDir);
      if (!planHash) {
        throw new Error('Transition Blocked: Missing or invalid plan cryptographic approval (Gate 1).');
      }

      const isDirty = await gitStatusPorcelain(cwd);
      if (isDirty) {
        throw new Error(
          'Transition Blocked: You have uncommitted changes in your workspace. Please commit or stash them before transitioning phases to prevent data loss.',
        );
      }
      return true;
    },
    onEnter: async (targetDir, cwd) => {
      console.log('🧹 Exiting PLAN: Workspace is clean. Proceeding to IMPLEMENT phase.');

      const activePlan = await findLatestActivePlan(targetDir);
      if (activePlan) {
        // Programmatic verification of Plan structural content
        const validation = await validatePlanContent(activePlan);
        if (!validation.valid) {
          throw new Error(`Transition Blocked: Active plan has invalid structure! ${validation.errors.join(', ')}`);
        }

        const planName = path
          .basename(activePlan, '.md')
          .toLowerCase()
          .replace(/[^a-z0-9_-]/g, '-');
        const branchName = `feature/${planName}`;

        const currentBranch = await gitBranchShowCurrent(cwd);
        if (currentBranch !== branchName) {
          console.log(`🌿 Switching to feature branch: ${branchName}`);
          try {
            const branchesOutput = await gitBranchList(cwd);
            const branches = branchesOutput
              .split('\n')
              .map((b) => b.trim())
              .filter(Boolean);
            if (branches.includes(branchName)) {
              await gitSwitch(branchName, cwd);
            } else {
              await gitCheckoutNewBranch(branchName, cwd);
            }
          } catch (err) {
            throw new Error(`Failed to switch to branch ${branchName}: ${err.message}`, { cause: err });
          }
        }
      }
    },
  },
  review: {
    canEnter: async (targetDir) => {
      const planHash = await verifyPlanGate(targetDir);
      if (!planHash) {
        throw new Error('Transition Blocked: Missing or invalid plan cryptographic approval (Gate 1).');
      }
      return true;
    },
    onEnter: async () => {},
  },
  commit: {
    canEnter: async (targetDir, cwd) => {
      const planHash = await verifyPlanGate(targetDir);
      if (!planHash) {
        throw new Error('Transition Blocked: Missing or invalid plan cryptographic approval (Gate 1).');
      }

      const diffHash = await gitDiff('HEAD', cwd);
      const diffHashClean = calculateSha256(diffHash);

      const reviewPassed = await verifyReviewGate(targetDir, diffHashClean, planHash);
      if (!reviewPassed) {
        throw new Error(
          'Transition Blocked: Missing or invalid review approval (Gate 2). Get code review sign-off first.',
        );
      }
      return true;
    },
    onEnter: async () => {},
  },
};

export async function transitionPhase(targetDir, targetPhase, cwd = process.cwd()) {
  const allowedPhases = ['plan', 'implement', 'review', 'commit'];
  if (!allowedPhases.includes(targetPhase)) {
    throw new Error(`Invalid phase: ${targetPhase}. Allowed: ${allowedPhases.join(', ')}`);
  }

  const state = (await readState(targetDir)) || { currentPhase: 'plan' };
  const currentPhase = state.currentPhase;
  console.log(`🔄 Attempting transition: ${currentPhase.toUpperCase()} -> ${targetPhase.toUpperCase()}`);

  if (targetPhase === currentPhase) {
    console.log(`ℹ️ Already in phase: ${targetPhase.toUpperCase()}`);
    return state;
  }

  try {
    const strategy = TRANSITION_STRATEGIES[targetPhase];
    if (strategy) {
      await strategy.canEnter(targetDir, cwd);
      await strategy.onEnter(targetDir, cwd);
    }
  } catch (err) {
    // Perform fail-safe state and approval revocation on any validation blockages
    await healApprovalState(targetDir, 'all');
    throw err;
  }

  // Authorized
  const newState = await setPhase(targetDir, targetPhase);
  console.log(`✅ Transitioned successfully to phase: ${targetPhase.toUpperCase()}`);
  return newState;
}

export async function setPhase(targetDir, phase) {
  if (!PHASE_CONFIG[phase]) {
    throw new Error(`Invalid phase: ${phase}`);
  }
  const state = (await readState(targetDir)) || {};
  state.currentPhase = phase;
  state.locked = PHASE_CONFIG[phase].locked;
  state.keyTool = PHASE_CONFIG[phase].keyTool;
  await writeState(targetDir, state);
  return state;
}

export async function setLock(targetDir, locked, keyTool = '') {
  const state = (await readState(targetDir)) || { currentPhase: 'plan' };
  state.locked = locked;
  state.keyTool = locked ? keyTool : '';
  await writeState(targetDir, state);
  return state;
}

export async function updateState(targetDir, updates) {
  let state = (await readState(targetDir)) || (await initializeState(targetDir));
  state = { ...state, ...updates };
  await writeState(targetDir, state);
  return state;
}
