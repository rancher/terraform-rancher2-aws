import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import path from 'path';
import { writeFileSafe, readFileSafe, fileExistsSafe, deleteFileSafe, resolveTargetDir } from '../file.js';
import { healApprovalState } from '../approval.js';
import { gitRevParseShowToplevel } from '../git.js';

test('file.js utilities tests', async (t) => {
  const tempFile = path.resolve('agent-scripts/lib/tests/temp-test-file.txt');

  t.after(() => {
    if (fs.existsSync(tempFile)) {
      fs.unlinkSync(tempFile);
    }
  });

  await t.test('writeFileSafe and readFileSafe work as expected', async () => {
    const testContent = 'Hello, this is a test!';
    await writeFileSafe(tempFile, testContent);
    assert.strictEqual(fs.existsSync(tempFile), true);

    const readContent = await readFileSafe(tempFile);
    assert.strictEqual(readContent, testContent);
  });

  await t.test('fileExistsSafe works for existing and non-existing files', () => {
    assert.strictEqual(fileExistsSafe(tempFile), true);
    assert.strictEqual(fileExistsSafe('non-existent-file-path.txt'), false);
  });

  await t.test('deleteFileSafe successfully removes the file', async () => {
    const result = await deleteFileSafe(tempFile);
    assert.strictEqual(result, true);
    assert.strictEqual(fs.existsSync(tempFile), false);
  });

  await t.test('resolveTargetDir resolves correct temporary directory', async () => {
    const targetDir = await resolveTargetDir();
    const topLevel = await gitRevParseShowToplevel();
    const repoName = path.basename(topLevel);
    assert.ok(targetDir.endsWith(path.join('.gemini', 'tmp', repoName)));
  });

  await t.test('healApprovalState purges files for correct gates', async () => {
    const testDir = path.resolve('agent-scripts/lib/tests/temp_heal_test');
    if (!fs.existsSync(testDir)) {
      fs.mkdirSync(testDir, { recursive: true });
    }

    const files = [
      'plan-approval.json',
      'plan-approval.json.sig',
      'review-approval.json',
      'user-approval.json',
      'user-approval.json.sig',
      'require-ask-user.flag',
    ];

    const createFiles = () => {
      files.forEach((f) => fs.writeFileSync(path.join(testDir, f), '{}'));
    };

    // Test 'plan' gate
    createFiles();
    await healApprovalState(testDir, 'plan');
    assert.strictEqual(fs.existsSync(path.join(testDir, 'plan-approval.json')), false);
    assert.strictEqual(fs.existsSync(path.join(testDir, 'plan-approval.json.sig')), false);
    assert.strictEqual(fs.existsSync(path.join(testDir, 'review-approval.json')), true);

    // Test 'review' gate
    createFiles();
    await healApprovalState(testDir, 'review');
    assert.strictEqual(fs.existsSync(path.join(testDir, 'review-approval.json')), false);
    assert.strictEqual(fs.existsSync(path.join(testDir, 'plan-approval.json')), true);

    // Test 'commit' gate
    createFiles();
    await healApprovalState(testDir, 'commit');
    assert.strictEqual(fs.existsSync(path.join(testDir, 'user-approval.json')), false);
    assert.strictEqual(fs.existsSync(path.join(testDir, 'user-approval.json.sig')), false);
    assert.strictEqual(fs.existsSync(path.join(testDir, 'require-ask-user.flag')), false);
    assert.strictEqual(fs.existsSync(path.join(testDir, 'plan-approval.json')), true);

    // Test 'all' gates
    createFiles();
    await healApprovalState(testDir, 'all');
    files.forEach((f) => {
      assert.strictEqual(fs.existsSync(path.join(testDir, f)), false);
    });

    // Cleanup
    try {
      fs.rmSync(testDir, { recursive: true, force: true });
    } catch (err) {
      console.warn(`Failed to cleanup temp test dir: ${err.message}`);
    }
  });
});
