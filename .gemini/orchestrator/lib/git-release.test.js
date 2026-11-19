import assert from 'node:assert';
import test from 'node:test';
import { affectsProductFiles, getGitDiff, stripDiffMetadata } from './git-release.js';

test('stripDiffMetadata', async (t) => {
  await t.test('filters index lines and chunk header @@ lines with line number shifts', () => {
    const diff1 = [
      'diff --git a/file.txt b/file.txt',
      'index 1234567..89abcdef 100644',
      '--- a/file.txt',
      '+++ b/file.txt',
      '@@ -10,3 +10,4 @@',
      ' context line',
      '+added line',
      ' context line 2',
    ].join('\n');

    const diff2 = [
      'diff --git a/file.txt b/file.txt',
      'index fedcba9..7654321 100644',
      '--- a/file.txt',
      '+++ b/file.txt',
      '@@ -45,3 +45,4 @@',
      ' context line',
      '+added line',
      ' context line 2',
    ].join('\n');

    const stripped1 = stripDiffMetadata(diff1);
    const stripped2 = stripDiffMetadata(diff2);

    assert.strictEqual(stripped1, stripped2);
    assert.doesNotMatch(stripped1, /^index /m);
    assert.match(stripped1, /^@@ @@$/m);
  });

  await t.test('retains hunk location context while ignoring line number shifts', () => {
    const diffFoo1 = [
      'diff --git a/file.txt b/file.txt',
      '--- a/file.txt',
      '+++ b/file.txt',
      '@@ -10,3 +10,4 @@ func Foo()',
      ' context line',
      '+added line',
      ' context line 2',
    ].join('\n');

    const diffFoo2 = [
      'diff --git a/file.txt b/file.txt',
      '--- a/file.txt',
      '+++ b/file.txt',
      '@@ -80,3 +80,4 @@ func Foo()',
      ' context line',
      '+added line',
      ' context line 2',
    ].join('\n');

    const diffBar = [
      'diff --git a/file.txt b/file.txt',
      '--- a/file.txt',
      '+++ b/file.txt',
      '@@ -10,3 +10,4 @@ func Bar()',
      ' context line',
      '+added line',
      ' context line 2',
    ].join('\n');

    assert.strictEqual(stripDiffMetadata(diffFoo1), stripDiffMetadata(diffFoo2));
    assert.notStrictEqual(stripDiffMetadata(diffFoo1), stripDiffMetadata(diffBar));
  });

  await t.test('preserves whitespace in diff content lines and trailing newlines', () => {
    const diffWithTrailingSpace = [
      'diff --git a/file.txt b/file.txt',
      '--- a/file.txt',
      '+++ b/file.txt',
      '@@ -1,2 +1,2 @@',
      '+added line with spaces   ',
      ' context line',
      '',
    ].join('\n');

    const diffWithoutTrailingSpace = [
      'diff --git a/file.txt b/file.txt',
      '--- a/file.txt',
      '+++ b/file.txt',
      '@@ -1,2 +1,2 @@',
      '+added line with spaces',
      ' context line',
      '',
    ].join('\n');

    const strippedWith = stripDiffMetadata(diffWithTrailingSpace);
    const strippedWithout = stripDiffMetadata(diffWithoutTrailingSpace);

    assert.match(strippedWith, /\+added line with spaces {3}\n/);
    assert.notStrictEqual(strippedWith, strippedWithout);
    assert.ok(strippedWith.endsWith('\n'));
  });
});

test('getGitDiff and affectsProductFiles', async (t) => {
  await t.test('getGitDiff returns a string', async () => {
    const diff = await getGitDiff();
    assert.strictEqual(typeof diff, 'string');
  });

  await t.test('affectsProductFiles returns a boolean', async () => {
    const isProduct = await affectsProductFiles();
    assert.strictEqual(typeof isProduct, 'boolean');
  });
});
