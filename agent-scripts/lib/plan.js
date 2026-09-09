import crypto from 'crypto';
import fs, { promises as fsPromises } from 'fs';
import path from 'path';
import { fileExistsSafe, readFileSafe, writeFileSafe, resolveTargetDir } from './file.js';

export async function findLatestActivePlan(targetDir) {
  try {
    if (!fs.existsSync(targetDir)) {
      return null;
    }
    const activeSessions = await fsPromises.readdir(targetDir);
    const planFiles = [];

    for (const session of activeSessions) {
      const plansPath = path.join(targetDir, session, 'plans');
      if (fs.existsSync(plansPath) && (await fsPromises.stat(plansPath)).isDirectory()) {
        const files = await fsPromises.readdir(plansPath);
        for (const file of files) {
          if (file.endsWith('.md')) {
            const filePath = path.join(plansPath, file);
            const stat = await fsPromises.stat(filePath);
            planFiles.push({
              path: filePath,
              mtime: stat.mtimeMs,
            });
          }
        }
      }
    }

    if (planFiles.length === 0) {
      return null;
    }

    planFiles.sort((a, b) => b.mtime - a.mtime);
    return planFiles[0].path;
  } catch (err) {
    console.error(`::error::findLatestActivePlan failed: ${err.message}`);
    return null;
  }
}

export async function readPlan(targetDir) {
  const planPath = await findLatestActivePlan(targetDir);
  if (!planPath) {
    return null;
  }
  return await readFileSafe(planPath);
}

export async function updatePlan(targetDir, content) {
  const planPath = await findLatestActivePlan(targetDir);
  if (!planPath) {
    return false;
  }
  try {
    await writeFileSafe(planPath, content);
    return true;
  } catch (err) {
    console.error(`::error::updatePlan failed: ${err.message}`);
    return false;
  }
}

export async function calculatePlanChecksum(targetDir) {
  const planPath = await findLatestActivePlan(targetDir);
  if (!planPath) {
    return null;
  }
  try {
    const content = await readFileSafe(planPath, null);
    if (!content) {
      return null;
    }
    return crypto.createHash('sha256').update(content).digest('hex');
  } catch (err) {
    console.error(`::error::calculatePlanChecksum failed: ${err.message}`);
    return null;
  }
}

/**
 * Programmatically validates that a plan file contains all of our strict requirements.
 * @param {string} planPath - The path to the active plan markdown file
 * @returns {Promise<object>} - { valid: boolean, errors: string[] }
 */
export async function validatePlanContent(planPath) {
  const errors = [];

  const content = await readFileSafe(planPath);
  if (!content) {
    return { valid: false, errors: ['Plan file does not exist or could not be read.'] };
  }

  // 1. Checklist check: must contain markdown checklist items "[ ]"
  const checklistMatch = /-\s*\[\s*\]/g.test(content);
  if (!checklistMatch) {
    errors.push('The plan must include each step in a checklist (using "- [ ]").');
  }

  // 2. Comprehensive tests check
  const testMatch = /test|testing|linter/i.test(content);
  if (!testMatch) {
    errors.push('The plan must include running comprehensive tests.');
  }

  // 3. Quality gates check
  const gateMatch = /gate|signature|seal|approval/i.test(content);
  if (!gateMatch) {
    errors.push('The plan must include our standard quality gates.');
  }

  // 4. Maintaining the agentic framework check
  const frameworkMatch = /agentic framework|system script|enforcer hook/i.test(content);
  if (!frameworkMatch) {
    errors.push('The plan must include maintaining the agentic framework if improvements or bugs are found in it.');
  }

  // 5. Updating documentation check
  const docMatch = /document|documentation|docs\//i.test(content);
  if (!docMatch) {
    errors.push('The plan must include updating documentation to describe the changes we plan to make.');
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

export async function validatePlan(targetDir) {
  const planPath = await findLatestActivePlan(targetDir);
  if (!planPath) {
    return { valid: false, errors: ['No active plan found.'] };
  }
  return await validatePlanContent(planPath);
}

/**
 * Checks if there is an active plan in the ~/.gemini/tmp/<repo>/session[star]/plans/ directory.
 * @param {string} cwd - The current working directory
 * @returns {Promise<boolean>} - True if an active plan exists, false otherwise
 */
export async function checkActivePlan(cwd) {
  try {
    const targetDir = await resolveTargetDir(cwd);
    if (!fileExistsSafe(targetDir)) {
      return false;
    }
    return (await findLatestActivePlan(targetDir)) !== null;
  } catch (err) {
    console.log(`::error::Failed to check for active plans: ${err.message || err}`);
    return false;
  }
}
