import { spawn } from 'child_process';
import { gitBranchShowCurrent } from './git.js';

/**
 * Safely executes the `gh` CLI, returning stdout.
 * Bypasses the shell for maximum security against injection.
 */
export function runGh(args, options = {}) {
  const { envOverrides = {}, cwd = process.cwd() } = options;
  const env = { ...process.env, ...envOverrides };
  const spawnOptions = {
    cwd,
    env,
  };

  return new Promise((resolve, reject) => {
    const child = spawn('gh', args, spawnOptions);
    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    child.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    child.on('error', (err) => {
      reject(new Error(`Failed to execute gh: ${err.message}`));
    });

    child.on('close', async (code) => {
      if (code !== 0) {
        // Smart fallback: If gh fails and GITHUB_TOKEN is set, retry using the native keychain auth.
        if (env.GITHUB_TOKEN) {
          const fallbackEnv = { ...env };
          delete fallbackEnv.GITHUB_TOKEN;
          try {
            const fallbackResult = await runGh(args, { ...options, envOverrides: { GITHUB_TOKEN: undefined } });
            resolve(fallbackResult);
            return;
          } catch {
            // If fallback also fails, reject with original error
          }
        }
        reject(new Error(`gh ${args.join(' ')} failed:\n${stderr || stdout}`));
      } else {
        resolve(stdout.trim());
      }
    });
  });
}

/**
 * Helper to extract owner and repo from a PR number
 */
export async function getRepoContext(prNumber) {
  const out = await runGh(['pr', 'view', String(prNumber), '--json', 'url'], {});
  const url = JSON.parse(out).url;
  // URL format: https://github.com/owner/repo/pull/123
  const parts = url.split('/');
  return { owner: parts[3], repo: parts[4] };
}

export async function exists(branch, owner, cwd = process.cwd()) {
  const head = owner ? `${owner}:${branch}` : branch;
  const out = await runGh(['pr', 'list', '--state', 'open', '--head', head, '--json', 'number'], { cwd });
  const prs = JSON.parse(out);
  return prs.length > 0 ? prs[0].number : null;
}

export async function detectPrId(cwd = process.cwd()) {
  const branch = await gitBranchShowCurrent(cwd);
  if (branch) {
    console.log(`Autodetecting open PR for branch '${branch}'...`);
    const prId = await exists(branch, null, cwd);
    if (prId) {
      return prId;
    }
  }
  return null;
}

export async function create({ title, body, base = 'main', head, draft = true, repo }, cwd = process.cwd()) {
  const args = ['pr', 'create', '--title', title, '--body', body, '--base', base];
  if (head) {
    args.push('--head', head);
  }
  if (draft) {
    args.push('--draft');
  }
  if (repo) {
    args.push('--repo', repo);
  }
  return await runGh(args, { cwd });
}

export async function update(prNumber, { title, body }, cwd = process.cwd()) {
  const args = ['pr', 'edit', String(prNumber)];
  if (title) {
    args.push('--title', title);
  }
  if (body) {
    args.push('--body', body);
  }
  await runGh(args, { cwd });
}

export async function close(prNumber, cwd = process.cwd()) {
  await runGh(['pr', 'close', String(prNumber)], { cwd });
}

export async function comment(prNumber, body, cwd = process.cwd()) {
  await runGh(['pr', 'comment', String(prNumber), '--body', body], { cwd });
}

export async function getGeneralComments(prNumber, cwd = process.cwd()) {
  const out = await runGh(['pr', 'view', String(prNumber), '--json', 'comments'], { cwd });
  return JSON.parse(out).comments;
}

export async function getReviewThreads(prNumber, cwd = process.cwd()) {
  const { owner, repo } = await getRepoContext(prNumber);
  const query = `
      query($owner: String!, $repo: String!, $pullNumber: Int!) {
        repository(owner: $owner, name: $repo) {
          pullRequest(number: $pullNumber) {
            reviewThreads(first: 100) {
              nodes {
                id
                isResolved
                comments(first: 50) {
                  nodes {
                    id
                    databaseId
                    body
                    path
                    author { login }
                    createdAt
                  }
                }
              }
            }
          }
        }
      }
    `;
  const out = await runGh(
    [
      'api',
      'graphql',
      '-F',
      `owner=${owner}`,
      '-F',
      `repo=${repo}`,
      '-F',
      `pullNumber=${prNumber}`,
      '-f',
      `query=${query}`,
    ],
    { cwd },
  );
  const data = JSON.parse(out);
  return data.data.repository.pullRequest.reviewThreads.nodes;
}

export async function replyToReviewComment(prNumber, commentId, body, cwd = process.cwd()) {
  const { owner, repo } = await getRepoContext(prNumber);
  await runGh(
    [
      'api',
      `repos/${owner}/${repo}/pulls/${prNumber}/comments/${commentId}/replies`,
      '-X',
      'POST',
      '-f',
      `body=${body}`,
    ],
    { cwd },
  );
}

export async function resolveReviewThread(threadId, cwd = process.cwd()) {
  const mutation = `mutation($threadId: ID!) { resolveReviewThread(input: {threadId: $threadId}) { thread { isResolved } } }`;
  await runGh(['api', 'graphql', '-F', `threadId=${threadId}`, '-f', `query=${mutation}`], { cwd });
}

export async function resolveThread(threadId, filePath, author, cwd = process.cwd()) {
  console.log(`Resolving thread ${threadId} on '${filePath}' by @${author}...`);
  try {
    await resolveReviewThread(threadId, cwd);
    console.log('✅ Thread successfully resolved!');
  } catch (err) {
    console.error(`❌ Failed to resolve thread ${threadId}: ${err.message}`);
  }
}

export async function view(target, fields = ['state', 'number', 'url', 'isDraft'], cwd = process.cwd()) {
  try {
    const out = await runGh(['pr', 'view', String(target), '--json', fields.join(',')], { cwd });
    return JSON.parse(out);
  } catch (err) {
    if (err.message.includes('no pull requests found') || err.message.includes('could not find pull request')) {
      return null;
    }
    throw err;
  }
}

export async function ready(target, cwd = process.cwd()) {
  const args = ['pr', 'ready'];
  if (target) {
    args.push(String(target));
  }
  await runGh(args, { cwd });
}

export async function getDefaultBranch(cwd = process.cwd()) {
  return await runGh(['repo', 'view', '--json', 'defaultBranchRef', '-q', '.defaultBranchRef.name'], { cwd });
}

export async function listUrl(branch, cwd = process.cwd()) {
  const out = await runGh(['pr', 'list', '--head', branch, '--json', 'url'], { cwd });
  const prs = JSON.parse(out);
  return prs.length > 0 ? prs[0].url : null;
}

export async function setDefaultRepo(upstreamRepo, cwd = process.cwd()) {
  await runGh(['repo', 'set-default', upstreamRepo], { cwd });
}

export async function getAllComments(prNumber, cwd = process.cwd()) {
  const { owner, repo } = await getRepoContext(prNumber);
  const genOut = await runGh(['api', `repos/${owner}/${repo}/issues/${prNumber}/comments`, '--paginate'], { cwd });
  const revOut = await runGh(['api', `repos/${owner}/${repo}/pulls/${prNumber}/comments`, '--paginate'], { cwd });
  const gen = JSON.parse(genOut || '[]').map((c) => ({ ...c, type: 'general' }));
  const rev = JSON.parse(revOut || '[]').map((c) => ({ ...c, type: 'review' }));
  return [...gen, ...rev].sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
}

export function formatComments(comments, format = 'markdown') {
  if (format === 'json') {
    return JSON.stringify(comments, null, 2);
  }
  if (comments.length === 0) {
    return 'No comments found.';
  }
  return comments
    .map((c) => {
      const icon = c.type === 'general' ? '💬' : '📝';
      const typeStr =
        c.type === 'general'
          ? 'General Comment'
          : `Inline Review on \`${c.path || 'unknown_file'}:${c.line || c.original_line || 'unknown'}\``;
      const date = c.created_at.replace('T', ' ').replace('Z', ' UTC');
      return `### ${icon} @${c.user.login} (${typeStr}) - ${date}\n\n${c.body}\n\n---`;
    })
    .join('\n');
}
