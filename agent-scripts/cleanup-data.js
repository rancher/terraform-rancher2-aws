#!/usr/bin/env node
import fs from 'fs';
import os from 'os';
import path from 'path';
import { fileExistsSafe, readdirSafe, statSafe, deleteFileSafe, readFileSafe } from './tools/file.js';

const tmpBaseDir = path.join(os.homedir(), '.gemini/tmp/terraform-provider-file');
const logsFilePath = path.join(tmpBaseDir, 'logs.json');

// Regex to extract UUID from file/directory names
const uuidRegex = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/;

async function getActiveSessionId() {
  try {
    if (fileExistsSafe(logsFilePath)) {
      const logsContent = await readFileSafe(logsFilePath, 'utf-8');
      if (logsContent) {
        const logs = JSON.parse(logsContent);
        if (Array.isArray(logs) && logs.length > 0) {
          const lastLog = logs[logs.length - 1];
          if (lastLog && lastLog.sessionId) {
            return lastLog.sessionId;
          }
        }
      }
    }
  } catch (err) {
    console.error(`⚠️ Failed to parse logs.json: ${err.message}`);
  }
  return null;
}

async function main() {
  const activeSession = await getActiveSessionId();
  if (!activeSession) {
    console.error(
      '❌ Could not dynamically determine the active session ID. Aborting cleanup to prevent deleting active session data.',
    );
    process.exit(1);
  }

  console.log(`ℹ️ Detected active session: ${activeSession}`);

  if (!fileExistsSafe(tmpBaseDir)) {
    console.log('ℹ️ Temp base directory does not exist. Nothing to clean up.');
    return;
  }

  let entries = [];
  try {
    entries = await readdirSafe(tmpBaseDir);
  } catch (err) {
    console.error(`❌ Failed to read temp directory: ${err.message}`);
    process.exit(1);
  }

  for (const entry of entries) {
    const entryPath = path.join(tmpBaseDir, entry);

    try {
      const stats = await statSafe(entryPath);
      const isDirectory = stats.isDirectory();

      // Clear out all tool-outputs, signatures, approvals, reports, remediation steps, logs (excluding logs.json), phase state, and PDFs
      if (
        entry.includes('tool-output') ||
        entry.endsWith('.sig') ||
        entry.endsWith('.bak') ||
        entry.includes('approval.') ||
        entry.endsWith('-report.md') ||
        entry === 'remediation-report.md' ||
        entry === 'logs' ||
        entry === 'phase-state.json' ||
        entry.endsWith('.pdf')
      ) {
        if (isDirectory) {
          console.log(`🧹 Removing temporary directory: ${entry}`);
          fs.rmSync(entryPath, { recursive: true, force: true });
        } else {
          console.log(`🧹 Removing temporary file: ${entry}`);
          await deleteFileSafe(entryPath);
        }
        continue;
      }

      const match = entry.match(uuidRegex);

      // Check if the entry name contains a session ID
      if (match) {
        const sessionId = match[0];
        if (sessionId !== activeSession) {
          if (isDirectory) {
            console.log(`🧹 Removing stale session directory: ${entry}`);
            fs.rmSync(entryPath, { recursive: true, force: true });
          } else {
            console.log(`🧹 Removing stale session chat/file: ${entry}`);
            await deleteFileSafe(entryPath);
          }
        }
      }
    } catch (err) {
      console.warn(`⚠️ Failed to inspect or remove ${entry}: ${err.message}`);
    }
  }
  console.log('✅ Cleanup complete.');
}

main().catch((err) => {
  console.error(`❌ Fatal Cleanup Error: ${err.stack || err.message}`);
  process.exit(1);
});
