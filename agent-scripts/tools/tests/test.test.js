import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { parseTestLogs } from '../test.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

test('tools test.js re-export tests', async (t) => {
  const tempLogFile = path.join(__dirname, 'temp-tool-test.log');

  t.after(() => {
    if (fs.existsSync(tempLogFile)) {
      fs.unlinkSync(tempLogFile);
    }
  });

  await t.test('parses go test -json lines via tool export', () => {
    const logData =
      [JSON.stringify({ Action: 'pass', Test: 'TestAwesomeToolFeature', Elapsed: 0.02 })].join('\n') + '\n';

    fs.writeFileSync(tempLogFile, logData);

    const result = parseTestLogs({ file: tempLogFile, noColor: true });
    assert.strictEqual(result.success, true);
    assert.ok(result.output.includes('PASSED TESTS (1):'));
    assert.ok(result.output.includes('✓ TestAwesomeToolFeature (0.02s)'));
  });
});
