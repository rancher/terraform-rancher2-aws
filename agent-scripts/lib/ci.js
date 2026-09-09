import { execFile } from 'child_process';
import fs from 'fs';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);
const DEFAULT_REPO = 'rancher/terraform-provider-file';

async function runWithRetry(file, args, maxAttempts = 5, baseDelay = 2) {
  let attempt = 1;
  while (true) {
    try {
      const { stdout } = await execFileAsync(file, args, { encoding: 'utf-8' });
      return stdout.trim();
    } catch (error) {
      if (attempt >= maxAttempts) {
        console.error(`Error: Command '${file} ${args.join(' ')}' failed after ${maxAttempts} attempts.`);
        throw error;
      }
      const delay = baseDelay * Math.pow(2, attempt - 1);
      console.warn(`Warning: Command failed. Retrying in ${delay} seconds (attempt ${attempt}/${maxAttempts})...`);
      await new Promise((resolve) => setTimeout(resolve, delay * 1000));
      attempt++;
    }
  }
}

export const ci = {
  /**
   * List recently failed CI runs via the GitHub CLI
   */
  async listFailedRuns(repo = DEFAULT_REPO) {
    try {
      const output = await runWithRetry('gh', [
        'run',
        'list',
        '-R',
        repo,
        '-s',
        'failure',
        '--limit',
        '10',
        '--json',
        'databaseId,workflowName,headBranch,createdAt,displayTitle',
      ]);
      return JSON.parse(output || '[]');
    } catch (error) {
      console.warn(`::warning::listFailedRuns failed: ${error.message || error}`);
      return [];
    }
  },

  /**
   * List failed jobs for a specific CI run using the GitHub API
   */
  async listFailedJobs(runId, repo = DEFAULT_REPO) {
    try {
      const output = await runWithRetry('gh', ['api', `repos/${repo}/actions/runs/${runId}/jobs`]);
      const data = JSON.parse(output);
      return (data.jobs || [])
        .filter((job) => job.conclusion === 'failure')
        .map((job) => ({ id: job.id.toString(), name: job.name }));
    } catch (error) {
      throw new Error(`Could not retrieve jobs for run ${runId}.`, { cause: error });
    }
  },

  /**
   * Get the latest run ID, optionally filtered by workflow or status
   */
  async getLatestRunId(workflow = '', status = '', repo = DEFAULT_REPO) {
    const args = ['run', 'list', '-R', repo, '--limit', '1', '--json', 'databaseId'];
    if (workflow) {
      args.push('-w', workflow);
    }
    if (status) {
      args.push('-s', status);
    }

    let originalError;
    try {
      const output = await runWithRetry('gh', args);
      const data = JSON.parse(output);
      if (data && data.length > 0 && data[0].databaseId) {
        return data[0].databaseId.toString();
      }
    } catch (error) {
      originalError = error;
    }
    throw new Error(`No recent workflow runs found matching the criteria for repository '${repo}'.`, {
      cause: originalError,
    });
  },

  /**
   * Download and save logs for a specific run or job directly via fs
   */
  async downloadLogs({ runId, jobId, repo = DEFAULT_REPO, outputPath }) {
    const finalOutputPath = outputPath || `/tmp/gh-${jobId ? 'job' : 'run'}-${jobId || runId || 'latest'}.log`;

    const args = jobId
      ? ['run', 'view', '--job', jobId, '-R', repo, '--log-failed']
      : ['run', 'view', runId || (await this.getLatestRunId('', '', repo)), '-R', repo, '--log-failed'];

    const output = await runWithRetry('gh', args);

    await fs.promises.writeFile(finalOutputPath, output, { encoding: 'utf-8' });
    return finalOutputPath;
  },
};

export default ci;
