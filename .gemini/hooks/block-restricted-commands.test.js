import assert from 'node:assert';
import { spawn } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath, URL } from 'node:url';

function runHook(inputPayload) {
  return new Promise((resolve, reject) => {
    const hookPath = fileURLToPath(new URL('./block-restricted-commands.js', import.meta.url));
    const child = spawn('node', [hookPath]);

    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    child.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    child.on('close', (code) => {
      resolve({ code, stdout, stderr });
    });

    child.on('error', (err) => {
      reject(err);
    });

    child.stdin.write(JSON.stringify(inputPayload));
    child.stdin.end();
  });
}

function parseJSON(stdout) {
  const lines = stdout.trim().split('\n');
  for (let i = lines.length - 1; i >= 0; i--) {
    try {
      return JSON.parse(lines[i]);
    } catch {
      // Continue scanning upward
    }
  }
  throw new Error(`Failed to parse JSON from stdout:\n${stdout}`);
}

test('block-restricted-commands.js deterministic guardrail rules', async (t) => {
  await t.test('blocks blacklisted paths like /var/ or /usr/ in write_file', async () => {
    const payload = {
      tool_name: 'write_file',
      tool_input: { file_path: '/usr/local/bin/some-script' },
    };
    const res = await runHook(payload);
    const parsed = parseJSON(res.stdout);
    assert.strictEqual(parsed.decision, 'deny');
  });

  await t.test('blocks id_rsa accesses', async () => {
    const payload = {
      tool_name: 'read_file',
      tool_input: { file_path: '~/.ssh/id_rsa' },
    };
    const res = await runHook(payload);
    const parsed = parseJSON(res.stdout);
    assert.strictEqual(parsed.decision, 'deny');
  });

  await t.test('blocks destructive shell commands (rm, chmod, chown, mv)', async () => {
    for (const cmd of ['rm -rf ./tmp', 'chmod +x script.sh', 'chown root:root file', 'mv old new']) {
      const payload = {
        tool_name: 'run_shell_command',
        tool_input: { command: cmd },
      };
      const res = await runHook(payload);
      const parsed = parseJSON(res.stdout);
      assert.strictEqual(parsed.decision, 'deny', `Expected "${cmd}" to be denied`);
    }
  });

  await t.test('blocks state-mutating git commands (commit, push, reset, checkout, rebase)', async () => {
    for (const cmd of [
      'git commit -m "fix"',
      'git push origin main',
      'git reset --hard HEAD~1',
      'git checkout main',
      'git rebase main',
    ]) {
      const payload = {
        tool_name: 'run_shell_command',
        tool_input: { command: cmd },
      };
      const res = await runHook(payload);
      const parsed = parseJSON(res.stdout);
      assert.strictEqual(parsed.decision, 'deny', `Expected "${cmd}" to be denied`);
    }
  });

  await t.test('allows safe read-only git commands (status, diff, log, rev-parse)', async () => {
    for (const cmd of ['git status', 'git diff HEAD', 'git log -n 5', 'git rev-parse --show-toplevel']) {
      const payload = {
        tool_name: 'run_shell_command',
        tool_input: { command: cmd },
      };
      const res = await runHook(payload);
      const parsed = parseJSON(res.stdout);
      assert.strictEqual(parsed.decision, 'allow', `Expected "${cmd}" to be allowed`);
    }
  });

  await t.test('allows normal harmless commands', async () => {
    const payload = {
      tool_name: 'run_shell_command',
      tool_input: { command: 'echo "hello"' },
    };
    const res = await runHook(payload);
    const parsed = parseJSON(res.stdout);
    assert.strictEqual(parsed.decision, 'allow');
  });

  await t.test('blocks invoke_agent tool calls', async () => {
    const payload = {
      tool_name: 'invoke_agent',
      tool_input: { agent_name: 'quality_assurance', prompt: 'test' },
    };
    const res = await runHook(payload);
    const parsed = parseJSON(res.stdout);
    assert.strictEqual(parsed.decision, 'deny');
    assert.match(parsed.reason, /potentially destructive/);
  });

  await t.test('outputs only valid JSON without unnecessary noise', async () => {
    const payload = {
      tool_name: 'run_shell_command',
      tool_input: { command: 'echo "hello"' },
    };
    const res = await runHook(payload);
    const lines = res.stdout.trim().split('\n');
    assert.strictEqual(lines.length, 1, 'Expected exactly one line of output');
    assert.doesNotThrow(() => JSON.parse(lines[0]), 'Expected output to be valid JSON');
  });

  await t.test(
    'blocks access to security-controlled .gemini files (.gemini/hooks/block-restricted-commands.js, .gemini/settings.json, including traversal)',
    async () => {
      for (const file of [
        '.gemini/hooks/block-restricted-commands.js',
        '.gemini/settings.json',
        './.gemini/hooks/block-restricted-commands.js',
        './.gemini/settings.json',
        '.gemini/hooks/../settings.json',
        '.gemini/hooks/../../.gemini/settings.json',
        '.gemini/hooks/../hooks/block-restricted-commands.js',
        '/absolute/path/.gemini/settings.json',
      ]) {
        const readPayload = {
          tool_name: 'read_file',
          tool_input: { file_path: file },
        };
        const readRes = await runHook(readPayload);
        const readParsed = parseJSON(readRes.stdout);
        assert.strictEqual(readParsed.decision, 'deny', `Expected reading "${file}" to be denied`);

        const writePayload = {
          tool_name: 'write_file',
          tool_input: { file_path: file },
        };
        const writeRes = await runHook(writePayload);
        const writeParsed = parseJSON(writeRes.stdout);
        assert.strictEqual(writeParsed.decision, 'deny', `Expected writing "${file}" to be denied`);

        const cmdPayload = {
          tool_name: 'run_shell_command',
          tool_input: { command: `cat ${file}` },
        };
        const cmdRes = await runHook(cmdPayload);
        const cmdParsed = parseJSON(cmdRes.stdout);
        assert.strictEqual(cmdParsed.decision, 'deny', `Expected command "cat ${file}" to be denied`);
      }
    },
  );

  await t.test('blocks shell interpreter payloads with -c or -e', async () => {
    const interpreterCmds = [
      "bash -c 'rm -rf ./tmp'",
      'sh -c "git push origin main"',
      'zsh -c "chmod +x script.sh"',
      "node -e \"require('fs').rmSync('./tmp', {recursive: true})\"",
      'python -c \'import os; os.system("rm -rf ./tmp")\'',
      'ruby -c \'system("git commit -m fix")\'',
      'perl -e \'system("mv old new")\'',
    ];
    for (const cmd of interpreterCmds) {
      const payload = {
        tool_name: 'run_shell_command',
        tool_input: { command: cmd },
      };
      const res = await runHook(payload);
      const parsed = parseJSON(res.stdout);
      assert.strictEqual(parsed.decision, 'deny', `Expected interpreter payload "${cmd}" to be denied`);
    }
  });

  await t.test('blocks wrapped and path-qualified destructive commands', async () => {
    const destructive = [
      '/bin/rm -rf ./tmp',
      '/usr/bin/rm -rf ./tmp',
      'command rm -rf ./tmp',
      'command -p rm -rf ./tmp',
      'sudo rm -rf ./tmp',
      'sudo /bin/rm -rf ./tmp',
      'env rm -rf ./tmp',
      'env -i rm -rf ./tmp',
      'VAR=1 /bin/rm -rf ./tmp',
      '/bin/mv old new',
      '/usr/bin/chmod +x script.sh',
      '/usr/sbin/chown root:root file',
      'echo hello && /bin/rm -rf ./tmp',
    ];
    for (const cmd of destructive) {
      const payload = {
        tool_name: 'run_shell_command',
        tool_input: { command: cmd },
      };
      const res = await runHook(payload);
      const parsed = parseJSON(res.stdout);
      assert.strictEqual(parsed.decision, 'deny', `Expected "${cmd}" to be denied`);
    }
  });

  await t.test('blocks wrapped and path-qualified mutating git commands', async () => {
    const mutating = [
      '/usr/bin/git commit -m "fix"',
      '/usr/bin/git push origin main',
      'command git checkout main',
      'sudo git reset --hard HEAD~1',
      'env git rebase main',
      'git -C ./repo commit -m "fix"',
      'git --no-pager push origin main',
    ];
    for (const cmd of mutating) {
      const payload = {
        tool_name: 'run_shell_command',
        tool_input: { command: cmd },
      };
      const res = await runHook(payload);
      const parsed = parseJSON(res.stdout);
      assert.strictEqual(parsed.decision, 'deny', `Expected "${cmd}" to be denied`);
    }
  });

  await t.test('allows wrapped or path-qualified safe read-only git commands', async () => {
    const safe = [
      '/usr/bin/git status',
      'command git diff HEAD',
      'git -C ./repo log -n 5',
      '/usr/bin/git rev-parse --show-toplevel',
    ];
    for (const cmd of safe) {
      const payload = {
        tool_name: 'run_shell_command',
        tool_input: { command: cmd },
      };
      const res = await runHook(payload);
      const parsed = parseJSON(res.stdout);
      assert.strictEqual(parsed.decision, 'allow', `Expected "${cmd}" to be allowed`);
    }
  });
});
