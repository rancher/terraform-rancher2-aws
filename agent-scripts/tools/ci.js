#!/usr/bin/env node
import process from 'process';
import { fileURLToPath } from 'url';
import { ci } from '../lib/ci.js';

export { ci };
export default ci;

// ==============================================================================
// CLI EXECUTION SUPPORT
// ==============================================================================
function showHelp() {
  console.log(`Usage: ci.js <command> [options]

Commands:
  list-failed [repo]                               List recently failed CI runs
  list-jobs <runId> [repo]                         List failed jobs for a specific CI run
  latest-run [workflow] [status] [repo]            Get the latest run ID
  download-logs <runId> <jobId> [repo] [outPath]   Download logs for a run or job
  help, -h, --help                                 Show this help message
`);
  process.exit(0);
}

async function main() {
  const command = process.argv[2];
  try {
    if (!command || command === 'help' || command === '-h' || command === '--help') {
      showHelp();
    } else if (command === 'list-failed') {
      console.log(JSON.stringify(await ci.listFailedRuns(process.argv[3]), null, 2));
    } else if (command === 'list-jobs') {
      console.log(JSON.stringify(await ci.listFailedJobs(process.argv[3], process.argv[4]), null, 2));
    } else if (command === 'latest-run') {
      console.log(await ci.getLatestRunId(process.argv[3], process.argv[4], process.argv[5]));
    } else if (command === 'download-logs') {
      const runId = process.argv[3] === 'null' ? null : process.argv[3];
      const jobId = process.argv[4] === 'null' ? null : process.argv[4];
      console.log(await ci.downloadLogs({ runId, jobId, repo: process.argv[5], outputPath: process.argv[6] }));
    } else {
      console.error(`Unknown command: ${command}`);
      process.exit(1);
    }
  } catch (err) {
    console.error(`CI command failed: ${err.message}`);
    process.exit(1);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main();
}
