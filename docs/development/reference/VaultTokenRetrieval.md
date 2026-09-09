# Auto-Merging Component: Vault Token Retrieval & Secret Management

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

## Abstract

The **Vault Token Retrieval & Secret Management** component is the authentication and privilege engine of the automated merging pipeline. Executed as a prerequisite step in the `merge-pr` job of `.github/workflows/pr-executor.yml`, this subsystem utilizes organization-level OpenID Connect (OIDC) trust relations to retrieve a short-lived, high-privilege GitHub installation token (`GITHUB_MERGE_TOKEN`) from HashiCorp Vault. This eliminates the need for hardcoded personal access tokens (PATs) or overly permissive default runner credentials.

---

## Technical Specification

### 1. Trigger & Authentication Flow

The Vault token retrieval step runs at the beginning of the `merge-pr` job, which only executes if the preceding `verify-pr` requirements check run has returned a successful conclusion.

The workflow uses GitHub's secure OIDC provider to authenticate with the HashiCorp Vault instance:

```text
  [ pr-executor.yml Runner ]
               │
               ├─► 1. Request OIDC ID token from GitHub Actions
               │
               ├─► 2. Authenticate with Vault using JWT & GitHub OIDC role
               │
               ├─► 3. Vault fetches dynamic GitHub App installation token
               │
               └─► 4. Vault returns short-lived token (GITHUB_MERGE_TOKEN)
```

1. **OIDC Token Issuance**: The runner requests a cryptographic JWT token from GitHub's OpenID Connect provider. The job must specify `permissions: id-token: write` to allow this token generation.
2. **Vault JWT Authentication**: The runner presents the JWT to the organizational Vault endpoint using the `rancher-eio/read-vault-secrets` action. Vault validates the token's claims (repository owner, repository name, branch, event) against its pre-configured trust policy.
3. **Dynamic Token Generation**: Upon successful authentication, Vault calls the GitHub API under an organization-level GitHub App registration to request a temporary installation access token scoped specifically to this repository.
4. **Token Injection**: Vault injects the high-privilege token into the job runner's environment variables as `GITHUB_MERGE_TOKEN`, where it is safely consumed by the subsequent merge execution script.

---

### 2. Secrets Scopes & Security Best Practices

### Dynamic Expiration

The token retrieved from Vault is extremely short-lived (typically expiring in under 60 minutes). This minimizes the blast radius of any leaked credentials and guarantees that the token cannot be used for subsequent persistent access.

### Scoped Permissions

The installation token is granted specific, narrow permissions on the target repository:

- **`contents: write`** (necessary to merge commits and write to repository branches)
- **`pull-requests: write`** (necessary to merge PRs and interact with PR threads)

### Strict Secret Masking

GitHub Actions automatically masks the retrieved `GITHUB_MERGE_TOKEN` in runner stdout/stderr logs. This prevents any accidental leaks in workflow run logs.

---

## Standing Implementation Decisions

### Zero Hardcoded Credentials

- No Personal Access Tokens (PATs) are allowed to be configured as repository secrets for automated merging. All write operations must rely strictly on dynamic Vault/OIDC installation tokens, upholding corporate security compliance.

### Path Boundaries

- In `.github/workflows/pr-executor.yml`, the Vault secret path is configured to load from:
  `github/token/rancher--terraform-provider-file--pull_requests--write`
  When transplanting this workflow, organizations must ensure their Vault pathing structure matches this path layout or adjust the path string accordingly.
