#!/usr/bin/env node
import process from 'process';
import { fileURLToPath } from 'url';

import {
  close,
  comment,
  create,
  detectPrId,
  exists,
  formatComments,
  getAllComments,
  getDefaultBranch,
  getGeneralComments,
  getReviewThreads,
  listUrl,
  ready,
  replyToReviewComment,
  resolveReviewThread,
  resolveThread,
  runGh,
  setDefaultRepo,
  update,
  view,
} from '../lib/pr.js';

export {
  close,
  comment,
  create,
  detectPrId,
  exists,
  formatComments,
  getAllComments,
  getDefaultBranch,
  getGeneralComments,
  getReviewThreads,
  listUrl,
  ready,
  replyToReviewComment,
  resolveReviewThread,
  resolveThread,
  runGh,
  setDefaultRepo,
  update,
  view,
};

function showHelp() {
  console.log(`Usage: pr.js <command> [args]

Commands:
  view <target> [fields]                        View PR details (JSON output). Fields comma separated.
  ready <target>                                Mark a draft PR as ready for review
  exists <branch> [owner]                       Check if an open PR exists for a branch (returns PR number)
  create <title> <body> [base] [head]           Open a new Draft PR
  update <prNumber> <title> <body>              Update the title and description of a PR
  close <prNumber>                              Close a PR
  comment <prNumber> <body>                     Add a general PR comment (outside of review)
  comments <prNumber>                           List general comments (JSON output)
  reviews <prNumber>                            List review comment threads (JSON output)
  all-comments <prNumber> [format]              List all general and review comments sorted chronologically (markdown or json)
  default-branch                                Get the default branch of the repository
  reply <prNumber> <commentId> <body>           Reply to a review comment in thread (requires comment databaseId)
  resolve <threadId>                            Resolve a PR review thread (requires GraphQL threadId)
  list-url <branch>                             Get the URL of the open PR for a branch
  set-default <repo>                            Set the default upstream repository (e.g. rancher/repo)
  execute <args...>                             Execute an arbitrary gh command
  help, -h, --help                              Show this help message
    `);
  process.exit(0);
}

async function main() {
  const command = process.argv[2];
  const args = process.argv.slice(3);

  try {
    if (!command || command === 'help' || command === '-h' || command === '--help') {
      showHelp();
    } else {
      switch (command) {
        case 'view': {
          const fields = args[1] ? args[1].split(',') : undefined;
          console.log(JSON.stringify(await view(args[0], fields), null, 2));
          break;
        }
        case 'ready':
          await ready(args[0]);
          console.log(`Successfully marked PR as ready for review`);
          break;
        case 'exists': {
          const prId = await exists(args[0], args[1]);
          if (prId) {
            console.log(prId);
          } else {
            console.log('Not found');
            process.exit(1);
          }
          break;
        }
        case 'create':
          console.log(
            await create({
              title: args[0],
              body: args[1],
              base: args[2],
              head: args[3],
            }),
          );
          break;
        case 'update':
          await update(args[0], { title: args[1], body: args[2] });
          console.log(`Successfully updated PR #${args[0]}`);
          break;
        case 'close':
          await close(args[0]);
          console.log(`Successfully closed PR #${args[0]}`);
          break;
        case 'comment':
          await comment(args[0], args[1]);
          console.log(`Successfully added comment to PR #${args[0]}`);
          break;
        case 'comments':
          console.log(JSON.stringify(await getGeneralComments(args[0]), null, 2));
          break;
        case 'reviews':
          console.log(JSON.stringify(await getReviewThreads(args[0]), null, 2));
          break;
        case 'default-branch':
          console.log(await getDefaultBranch());
          break;
        case 'all-comments': {
          const comments = await getAllComments(args[0]);
          console.log(formatComments(comments, args[1] || 'markdown'));
          break;
        }
        case 'reply':
          await replyToReviewComment(args[0], args[1], args[2]);
          console.log(`Successfully replied to comment ID ${args[1]} on PR #${args[0]}`);
          break;
        case 'resolve':
          await resolveReviewThread(args[0]);
          console.log(`Successfully resolved thread ${args[0]}`);
          break;
        case 'list-url': {
          const url = await listUrl(args[0]);
          if (url) {
            console.log(url);
          } else {
            console.log('Not found');
          }
          break;
        }
        case 'set-default':
          await setDefaultRepo(args[0]);
          console.log(`Successfully set default repo to ${args[0]}`);
          break;
        case 'execute':
          console.log(await runGh(args));
          break;
        default:
          console.error(`Error: Unknown command '${command}'\n`);
          showHelp();
      }
    }
  } catch (err) {
    console.error(`\nError executing PR tool: ${err.message}`);
    process.exit(1);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main();
}
