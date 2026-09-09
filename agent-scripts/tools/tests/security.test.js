import test from 'node:test';
import assert from 'node:assert';
import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const hookPath = path.resolve(__dirname, '../../../.gemini/hooks/block-restricted-commands.js');

function runHook(inputJson) {
  return new Promise((resolve, reject) => {
    const child = spawn('node', [hookPath], {
      stdio: ['pipe', 'pipe', 'ignore'],
    });

    let stdout = '';
    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    child.on('error', (err) => {
      reject(err);
    });

    child.on('close', (code) => {
      resolve({ code, stdout });
    });

    child.stdin.write(JSON.stringify(inputJson));
    child.stdin.end();
  });
}

test('block-restricted-commands hook security tests', async (t) => {
  await t.test('allows safe command like echo', async () => {
    const input = {
      tool_name: 'run_shell_command',
      tool_input: {
        command: "echo 'hello world'",
      },
    };
    const { code, stdout } = await runHook(input);
    assert.strictEqual(code, 0);
    const parsed = JSON.parse(stdout);
    assert.strictEqual(parsed.decision, 'allow');
  });

  await t.test('denies command that attempts to spoof GEMINI_TEST', async () => {
    const input = {
      tool_name: 'run_shell_command',
      tool_input: {
        command: "GEMINI_TEST=true echo 'bypass'",
      },
    };
    const { code, stdout } = await runHook(input);
    assert.strictEqual(code, 0);
    const parsed = JSON.parse(stdout);
    assert.strictEqual(parsed.decision, 'deny');
    assert.ok(parsed.systemMessage.includes('Restricted shell command denied.'));
  });

  await t.test('denies unsafe git push command', async () => {
    const input = {
      tool_name: 'run_shell_command',
      tool_input: {
        command: 'git push origin main',
      },
    };
    const { code, stdout } = await runHook(input);
    assert.strictEqual(code, 0);
    const parsed = JSON.parse(stdout);
    assert.strictEqual(parsed.decision, 'deny');
    assert.ok(parsed.systemMessage.includes('Restricted shell command denied.'));
  });
});
