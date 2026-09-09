#!/usr/bin/env node
import process from 'process';
import { fileURLToPath } from 'url';
import {
  deleteFileSafe,
  executeFileSafe,
  readFileSafe,
  writeFileSafe,
  fileExistsSafe,
  extractPlanContent,
  savePlanContent,
  calculateFileHash,
  diffPaths,
  resolveTargetDir,
  registerCleanupTraps,
  mkdtempSafe,
  copyFileSafe,
  readdirSafe,
  statSafe,
} from '../lib/file.js';

export {
  deleteFileSafe,
  executeFileSafe,
  readFileSafe,
  writeFileSafe,
  fileExistsSafe,
  extractPlanContent,
  savePlanContent,
  calculateFileHash,
  diffPaths,
  resolveTargetDir,
  registerCleanupTraps,
  mkdtempSafe,
  copyFileSafe,
  readdirSafe,
  statSafe,
};

function showHelp() {
  console.log(`Usage: file.js <command> [options]

Commands:
  read <file>                     Read and print file contents
  write <file> <content> [mode]   Write content to a file (optional octal mode, e.g., 0600)
  delete <file>                   Delete a file safely
  execute <file> [args...]        Execute a script file (args comma-separated)
  help, -h, --help                Show this help message
`);
  process.exit(0);
}

export async function handleFile(action, filePath, content = '', mode = null, args = '') {
  switch (action) {
    case 'write': {
      const options = mode ? { mode: parseInt(mode, 8) } : {};
      await writeFileSafe(filePath, content, options);
      console.log(`✅ Successfully wrote to ${filePath}`);
      break;
    }
    case 'read': {
      const data = await readFileSafe(filePath);
      if (data === null) {
        console.error(`❌ File not found: ${filePath}`);
        process.exit(1);
      }
      process.stdout.write(data);
      break;
    }
    case 'delete': {
      if (await deleteFileSafe(filePath)) {
        console.log(`✅ Successfully deleted ${filePath}`);
      } else {
        console.log(`⚠️ File not found, skipping delete: ${filePath}`);
      }
      break;
    }
    case 'execute': {
      const execArgs = args ? args.split(',').map((a) => a.trim()) : [];
      try {
        const output = await executeFileSafe(filePath, execArgs);
        if (output !== null) {
          console.log(`✅ Successfully executed ${filePath}`);
          if (typeof output === 'string' && output.trim()) {
            console.log(`\n--- Output ---\n${output.trim()}`);
          }
        }
      } catch (err) {
        console.error(`❌ Execution failed for ${filePath}: ${err.message || err}`);
        process.exit(1);
      }
      break;
    }
    default:
      console.error(`❌ Unknown action: '${action}'. Must be read, write, delete, or execute.`);
      process.exit(1);
  }
}

// ==============================================================================
// CLI EXECUTION SUPPORT
// ==============================================================================
async function main() {
  const command = process.argv[2];
  const filePath = process.argv[3];
  try {
    if (!command || command === 'help' || command === '-h' || command === '--help') {
      showHelp();
    } else if (command === 'read') {
      if (!filePath) {
        throw new Error('read requires <file>');
      }
      await handleFile('read', filePath);
    } else if (command === 'write') {
      if (!filePath) {
        throw new Error('write requires <file>');
      }
      await handleFile('write', filePath, process.argv[4] || '', process.argv[5]);
    } else if (command === 'delete') {
      if (!filePath) {
        throw new Error('delete requires <file>');
      }
      await handleFile('delete', filePath);
    } else if (command === 'execute') {
      if (!filePath) {
        throw new Error('execute requires <file>');
      }
      await handleFile('execute', filePath, '', null, process.argv[4] || '');
    } else {
      console.error(`Unknown command: ${command}`);
      process.exit(1);
    }
  } catch (err) {
    console.error(`File command failed: ${err.message}`);
    process.exit(1);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((err) => {
    console.error('::error::Fatal File Tool Error:', err.stack || err.message);
    process.exit(1);
  });
}
