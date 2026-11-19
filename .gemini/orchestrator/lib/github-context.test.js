import assert from 'node:assert';
import test from 'node:test';
import { getPRComments, sys } from './github-context.js';

test('github-context - getPRComments', async (t) => {
  await t.test('executes read_comments.js with arguments and returns formatted comments', async () => {
    let capturedCmd = null;
    let capturedArgs = null;
    let capturedOptions = null;

    t.mock.method(sys, 'execFileAsync', async (cmd, args, options) => {
      capturedCmd = cmd;
      capturedArgs = args;
      capturedOptions = options;
      return { stdout: '=== Comments for PR #448 ===\nSome mock comment text\n' };
    });

    const comments = await getPRComments(448);
    assert.strictEqual(typeof comments, 'string');
    assert.match(comments, /Comments for PR #448/);
    assert.strictEqual(capturedCmd, process.execPath);
    assert.ok(capturedArgs[0].endsWith('read_comments.js'));
    assert.strictEqual(capturedArgs[1], '448');
    assert.strictEqual(capturedOptions.maxBuffer, 10 * 1024 * 1024);
  });

  await t.test('propagates error message when child process fails', async () => {
    t.mock.method(sys, 'execFileAsync', async () => {
      const err = new Error('Process exited with code 1');
      err.stderr = 'API rate limit exceeded';
      throw err;
    });

    await assert.rejects(
      async () => {
        await getPRComments('448');
      },
      {
        message: /Failed to fetch PR comments programmatically: API rate limit exceeded/,
      },
    );
  });
});
