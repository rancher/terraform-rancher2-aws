export default async ({ github, context, core, process }) => {
  try {
    const prNumberStr = process.env.PR_NUMBER;
    if (!prNumberStr) {
      core.setFailed("PR_NUMBER environment variable is missing.");
      return;
    }
    const prNumber = parseInt(prNumberStr, 10);
    
    await github.rest.issues.createComment({
      issue_number: prNumber,
      owner: context.repo.owner,
      repo: context.repo.repo,
      body: `Please make sure e2e tests pass before merging this PR! \n ${process.env.GITHUB_SERVER_URL}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`
    });
  } catch (error) {
    core.setFailed(error.message);
  }
};
