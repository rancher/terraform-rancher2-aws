import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { parseTestLogs } from '../test.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

test('test.js parseTestLogs utility tests', async (t) => {
  const tempLogFile = path.join(__dirname, 'temp-test.log');

  t.after(() => {
    if (fs.existsSync(tempLogFile)) {
      fs.unlinkSync(tempLogFile);
    }
  });

  await t.test('parses go test -json lines and detects successes/failures correctly', () => {
    const logData =
      [
        JSON.stringify({ Action: 'pass', Test: 'TestAwesomeFeature', Elapsed: 0.05 }),
        JSON.stringify({ Action: 'fail', Test: 'TestBrokenFeature', Elapsed: 0.12 }),
        JSON.stringify({
          Action: 'fail',
          Package: 'github.com/rancher/terraform-provider-file/internal/provider',
          Elapsed: 0.45,
        }),
      ].join('\n') + '\n';

    fs.writeFileSync(tempLogFile, logData);

    const result = parseTestLogs({ file: tempLogFile, noColor: true });
    assert.strictEqual(result.success, false);
    assert.ok(result.output.includes('PASSED TESTS (1):'));
    assert.ok(result.output.includes('✓ TestAwesomeFeature (0.05s)'));
    assert.ok(result.output.includes('FAILED ITEMS (2):'));
    assert.ok(result.output.includes('✗ TestBrokenFeature (0.12s)'));
    assert.ok(
      result.output.includes('✗ Package: github.com/rancher/terraform-provider-file/internal/provider (0.45s)'),
    );
  });
});
