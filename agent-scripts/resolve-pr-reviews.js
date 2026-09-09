#!/usr/bin/env node
/**
 * Skill: resolve-pr-reviews.js
 * Description: Programmatically list and resolve review comment threads on a GitHub Pull Request.
 */

import { parseArgs } from 'node:util';
import { detectPrId, getReviewThreads, resolveThread } from './tools/pr.js';

function showHelp() {
  console.log(`Usage: resolve-pr-reviews.js [PR_ID] [options/file_pattern]

Programmatically list and resolve review comment threads on a GitHub Pull Request.

Arguments:
  PR_ID                 The numeric ID of the Pull Request (optional if on a branch with an open PR).
  OPTIONS/PATTERN       Filter or resolution command options.

Options:
  -h, --help            Show this message and exit.
  --all                 Resolve ALL unresolved comment threads.
  <pattern>             Resolve threads where the file path contains the given literal pattern.

Examples:
  agent-scripts/resolve-pr-reviews.js 390
  agent-scripts/resolve-pr-reviews.js 390 --all
  agent-scripts/resolve-pr-reviews.js 390 publish-release.test.js`);
}

function parseArguments() {
  const { values, positionals } = parseArgs({
    options: {
      help: { type: 'boolean', short: 'h' },
      all: { type: 'boolean' },
    },
    allowPositionals: true,
  });

  if (values.help) {
    showHelp();
    process.exit(0);
  }

  let prId = null;
  let filter = null;

  for (const pos of positionals) {
    if (/^\d+$/.test(pos)) {
      prId = pos;
    } else {
      filter = pos;
    }
  }

  const mode = values.all ? 'all' : filter ? 'filter' : 'list';
  return { prId, filter, mode };
}

async function processThreads(threads, mode, filter, prId) {
  if (threads.length === 0) {
    console.log(`🎉 No unresolved comment threads found on PR #${prId}!`);
    return;
  }

  console.log(`Found ${threads.length} unresolved comment thread(s) on PR #${prId}:`);

  for (const thread of threads) {
    const threadId = thread.id;
    const comment = thread.comments.nodes[0];
    const filePath = comment.path;
    const author = comment.author ? comment.author.login : 'unknown';
    const body = comment.body.replace(/\r|\n/g, ' ').substring(0, 80);

    console.log('------------------------------------------------------------');
    console.log(`Thread ID : ${threadId}`);
    console.log(`File Path : ${filePath}`);
    console.log(`Author    : @${author}`);
    console.log(`Comment   : ${body}...`);

    let shouldResolve = false;
    if (mode === 'all') {
      shouldResolve = true;
    } else if (mode === 'filter') {
      if (filePath.includes(filter)) {
        shouldResolve = true;
      } else {
        console.log('  -> Skipping (does not match filter)');
      }
    } else {
      console.log(
        `  -> Running in list mode. Run with 'agent-scripts/resolve-pr-reviews.js ${prId} --all' or 'agent-scripts/resolve-pr-reviews.js ${prId} ${filePath}' to resolve.`,
      );
    }

    if (shouldResolve) {
      try {
        await resolveThread(threadId, filePath, author);
      } catch (err) {
        console.error(`  -> Failed to resolve thread ${threadId}: ${err.message || err}`);
      }
    }
  }
  console.log('------------------------------------------------------------');
}

async function main() {
  const args = parseArguments();
  let prId = args.prId;
  const { filter, mode } = args;

  if (!prId) {
    prId = await detectPrId();
  }

  if (!prId) {
    console.error('Error: No Pull Request number provided and could not autodetect an open PR for the current branch.');
    process.exit(1);
  }

  if (mode === 'filter') {
    console.log(`Filtering threads containing file path pattern: '${filter}'`);
  }

  console.log(`Fetching unresolved review comment threads for PR #${prId}...`);
  let allThreads = [];
  try {
    allThreads = await getReviewThreads(prId);
  } catch (err) {
    console.error(`Error fetching threads: ${err.message}`);
    process.exit(1);
  }

  const unresolvedThreads = allThreads.filter((t) => !t.isResolved);
  await processThreads(unresolvedThreads, mode, filter, prId);
}

main().catch((err) => {
  console.error('::error::Fatal Resolve PR Reviews Error:', err.stack || err.message);
  process.exit(1);
});
