# Auto-Merging Component: Pull Request Triggers & Target Resolution

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

## Abstract

The **Pull Request Triggers & Target Resolution** component is the initial entry gate of the automated merging pipeline. Backed by `get-target-pr.js` and orchestrated via `.github/workflows/pr-executor.yml`, this subsystem asynchronously triggers on pull request activities, resolves the target PR context across multiple API fallbacks, and executes immediate security checks to safeguard release-critical branches.

---

## Technical Specification

### 1. Trigger Mechanics

The orchestrator workflow (`pr-executor.yml`) has no direct triggers of its own for general pull requests. Instead, it relies on two primary channels:

- **`workflow_run` (Asynchronous Completion)**: Triggers automatically upon the completion of either:
  - The `pull_request` workflow (which runs tests, linters, and compiles the code).
  - The `pull_request_review_trigger` workflow (which fires when reviews are submitted).
- **`workflow_dispatch` (Manual Override)**: Permits developers with repository write permissions to manually force a PR executor run from the GitHub Actions dashboard.

By triggering on `workflow_run` completion rather than on standard `pull_request` events directly, the merge executor runs in a secure `read-write` default token context (necessary to write comments and merge) while the actual tests and unvetted code run in a restricted `read-only` context.

### 2. Tiered Target PR Resolution (`get-target-pr.js`)

Because the workflow triggers on `workflow_run` completion, the default event payload context belongs to the parent workflow run, not the target Pull Request. To determine which PR to verify and merge, `get-target-pr.js` executes a tiered, paginated fallback loop:

```text
       [ parentRun Payload ]
                 │
                 ├─► 1. Extract from parentRun.pull_requests[0].number
                 │
                 ├─► 2. API: Fetch details via parentRun.id
                 │
                 ├─► 3. API: List associated PRs by head commit SHA
                 │
                 └─► 4. API: Paginate and filter all open PRs by branch/owner
```

1. **Direct Payload Extraction**: Checks if the parent workflow run payload directly exposes the associated pull requests array and extracts the first matching PR number.
2. **Workflow Run Detail Query**: If the payload is empty, it queries the GitHub REST API (`actions/github-script`) using the parent run ID to fetch the full execution metadata.
3. **Commit SHA Back-reference**: If no PR is directly linked, it extracts the parent run's head commit SHA (`parentRun.head_sha`) and queries `listPullRequestsAssociatedWithCommit` to locate open PRs matching the SHA.
4. **Branch & Repository Match**: As a final fallback, it retrieves all open PRs in the repository and filters them to identify a unique PR whose head branch name and fork owner match the parent workflow's head branch and head repository owner.

_Ambiguity Protection_: If fallbacks 3 or 4 return multiple matching open PRs, the script halts and sets the build status to failed to prevent applying automated merges to ambiguous contexts.

### 3. Immediate Safety Gates

Before returning the resolved PR number to the orchestrator, `get-target-pr.js` enforces a crucial security check:

- **Release-Please Exemption**: Checks if the PR author is `release-please[bot]` and if the branch ref starts with `release-please--`.
- If true, it immediately halts execution with a failed status message:
  `"Skipping execution: Release-please PR #<num> is strictly exempt from automated merging."`

This protects release-prep branches and automated changelog updates from being accidentally squash-merged by the bot before maintainers have reviewed the release versioning details.

---

## Standing Implementation Decisions

### Hermetic Workflow Execution

- **Run Environment**: Must execute strictly within the Nix CI container (`ghcr.io/rancher/ci-image/nix:...`) to prevent dependency contamination or environment changes.
- **Fail-Fast**: If the PR context is completely unresolved, the script must fail immediately rather than proceeding with default values, ensuring zero unvetted actions are taken on the repository.
