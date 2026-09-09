#!/usr/bin/env node
import process from 'process';
import { fileURLToPath } from 'url';
import {
  PHASE_CONFIG,
  initializeState,
  readState,
  setLock,
  setPhase,
  transitionPhase,
  updateState,
  getStatePath,
  writeState,
} from '../lib/state.js';
import { resolveTargetDir } from '../lib/file.js';

export {
  PHASE_CONFIG,
  initializeState,
  readState,
  setLock,
  setPhase,
  transitionPhase,
  updateState,
  getStatePath,
  writeState,
};

function showHelp() {
  console.log(`Usage: state.js <command> [options]

Commands:
  init                       Initialize phase-state.json with default plan state
  set-phase <phase>          Set the current phase (plan, implement, review, commit)
  transition [phase]         Attempt to transition to a new phase, enforcing rules and gates
  lock <keyTool>             Lock the state and require a specific tool to unlock
  unlock                     Unlock the state
  read                       Read and print the current state
  update <json>              Update the state with the provided JSON string
  help, -h, --help           Show this help message
`);
  process.exit(0);
}

async function main() {
  const command = process.argv[2];
  const targetDir = await resolveTargetDir();

  try {
    if (!command || command === 'help' || command === '-h' || command === '--help') {
      showHelp();
    } else if (command === 'init') {
      const state = await initializeState(targetDir);
      console.log(`✅ State initialized: \n${JSON.stringify(state, null, 2)}`);
    } else if (command === 'set-phase') {
      const phase = process.argv[3];
      if (!phase) {
        console.error('Error: set-phase requires <phase>');
        process.exit(1);
      }
      const state = await setPhase(targetDir, phase);
      console.log(`✅ Phase set to ${phase}: \n${JSON.stringify(state, null, 2)}`);
    } else if (command === 'transition') {
      const phase = process.argv[3];
      if (!phase) {
        const state = (await readState(targetDir)) || { currentPhase: 'plan' };
        console.log(`📍 Current development phase: ${state.currentPhase.toUpperCase()}`);
      } else {
        await transitionPhase(targetDir, phase);
      }
    } else if (command === 'lock') {
      const keyTool = process.argv[3];
      if (!keyTool) {
        console.error('Error: lock requires <keyTool>');
        process.exit(1);
      }
      const state = await setLock(targetDir, true, keyTool);
      console.log(`✅ State locked (keyTool: ${keyTool}): \n${JSON.stringify(state, null, 2)}`);
    } else if (command === 'unlock') {
      const state = await setLock(targetDir, false);
      console.log(`✅ State unlocked: \n${JSON.stringify(state, null, 2)}`);
    } else if (command === 'read') {
      const state = await readState(targetDir);
      if (state) {
        console.log(JSON.stringify(state, null, 2));
      } else {
        console.error('❌ State file not found or invalid.');
        process.exit(1);
      }
    } else if (command === 'update') {
      const jsonStr = process.argv[3];
      if (!jsonStr) {
        console.error('Error: update requires <json>');
        process.exit(1);
      }
      let updates;
      try {
        updates = JSON.parse(jsonStr);
      } catch (parseErr) {
        console.error(`Error: Failed to parse update JSON: ${parseErr.message}`);
        process.exit(1);
      }
      const state = await updateState(targetDir, updates);
      console.log(`✅ State updated: \n${JSON.stringify(state, null, 2)}`);
    } else {
      console.error(`Unknown command: ${command}`);
      process.exit(1);
    }
  } catch (err) {
    console.error(`State command failed: ${err.message}`);
    process.exit(1);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((err) => {
    console.error('::error::Fatal State Tool Error:', err.stack || err.message);
    process.exit(1);
  });
}
