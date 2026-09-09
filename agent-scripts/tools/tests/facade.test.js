import test from 'node:test';
import assert from 'node:assert';

import * as libFile from '../../lib/file.js';
import * as toolFile from '../file.js';

import * as libGit from '../../lib/git.js';
import * as toolGit from '../git.js';

import * as libApproval from '../../lib/approval.js';
import * as toolApproval from '../approval.js';

import * as libPlan from '../../lib/plan.js';
import * as toolPlan from '../plan.js';

import * as libState from '../../lib/state.js';
import * as toolState from '../state.js';

import * as libTest from '../../lib/test.js';
import * as toolTest from '../test.js';

test('facade re-export validation', async (t) => {
  const modules = [
    { name: 'file.js', lib: libFile, tool: toolFile },
    { name: 'git.js', lib: libGit, tool: toolGit },
    { name: 'approval.js', lib: libApproval, tool: toolApproval },
    { name: 'plan.js', lib: libPlan, tool: toolPlan },
    { name: 'state.js', lib: libState, tool: toolState },
    { name: 'test.js', lib: libTest, tool: toolTest },
  ];

  for (const { name, lib, tool } of modules) {
    await t.test(`should perfectly re-export all functions from lib/${name} into tools/${name}`, () => {
      for (const [key, value] of Object.entries(lib)) {
        if (typeof value === 'function') {
          assert.ok(key in tool, `Missing expected export '${key}' in tools/${name}`);
          assert.strictEqual(typeof tool[key], 'function', `Export '${key}' in tools/${name} is not a function`);
        }
      }
    });
  }
});
