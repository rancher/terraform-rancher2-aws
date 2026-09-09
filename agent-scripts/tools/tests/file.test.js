import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import path from 'path';
import { writeFileSafe, readFileSafe, resolveTargetDir } from '../file.js';
import { gitRevParseShowToplevel } from '../git.js';

test('tools file.js re-export tests', async (t) => {
  const tempFile = path.resolve('agent-scripts/tools/tests/temp-tool-test-file.txt');

  t.after(() => {
    if (fs.existsSync(tempFile)) {
      fs.unlinkSync(tempFile);
    }
  });

  await t.test('writeFileSafe and readFileSafe exported by tools work as expected', async () => {
    const testContent = 'Hello, this is a tool-level test!';
    await writeFileSafe(tempFile, testContent);
    assert.strictEqual(fs.existsSync(tempFile), true);

    const readContent = await readFileSafe(tempFile);
    assert.strictEqual(readContent, testContent);
  });

  await t.test('resolveTargetDir exported by tools works as expected', async () => {
    const targetDir = await resolveTargetDir();
    const topLevel = await gitRevParseShowToplevel();
    const repoName = path.basename(topLevel);
    assert.ok(targetDir.endsWith(path.join('.gemini', 'tmp', repoName)));
  });
});
