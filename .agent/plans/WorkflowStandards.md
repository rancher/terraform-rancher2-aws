# Workflow Refactor

**Executed Date:** 2026 August
**Purpose:** Update all workflows to have a standard step structure, extract all scripts so they can be linted, use commit hashes for action versioning, and implement least privilege security principle.

---

- All jobs must define explicit `permissions:`. All workflows should have `permissions: {}` at the top level. Set scopes to `none` as needed. Permissions should implement least privilege necessary access.
- Pin all actions (including `actions/*`, `github/*`, `rancher/*`) to a full 40-character commit SHA, not a tag. The `uses:` line MUST include the version (e.g., `# v6.0.2`). On the line before the `uses:` there should be a comment with a link to the releases page for the action (e.g. `# https://github.com/actions/github-script/releases`).
- Only pre-approved action namespaces are allowed. Approved namespaces are documented at: `https://github.com/rancher/security-team/blob/main/docs/standards/rancher-gha-standards.md#allowed-github-actions`. Important ones include: `https://github.com/actions/*`, `https://github.com/aquasecurity/*`, `https://github.com/aws-actions/*`, `https://github.com/dependabot/*`, `https://github.com/fossas/fossa-action@*`, `https://github.com/golang/*`, `https://github.com/golangci/*`, `https://github.com/google-github-actions/*`, `https://github.com/google/*`, `https://github.com/googleapis/release-please-action@*`, `https://github.com/goreleaser/*`, `https://github.com/hashicorp/setup-terraform@*`, `https://github.com/hashicorp/vault-action@*`, `https://github.com/rancher-eio/*`, `https://github.com/renovatebot/*`, and `https://github.com/updatecli/*`.
- Never inline untrusted context variables in `run` scripts. Use environment variables (e.g., `env: VAR: ${{...}}`).
- Remove and replace any `pull_request_target` triggered workflows, this trigger is banned.
- Every `job` must have an explicit `timeout-minutes`. Don't use the 360-minute default.
- Use `concurrency` blocks in PR workflows to cancel redundant runs (e.g., `group: ${{ github.workflow }}-${{ github.ref }}`).
- Suggest `actions/cache` or action-specific caching to speed up dependency downloads.
- Workflows should orchestrate, not execute. They may call out to external actions or internal scripts, but must not execute full steps by themselves. Replace any step which executes without calling out to an external action or internal script.
- All `run` or `github-script` scripts should be placed in the `.github/workflows/scripts` directory. Do not use inline JavaScript in `actions/github-script`.
- All scripts should be validated in the `pull_request.yaml` workflow. If any aren't validated, add them.
- All workflows, jobs, and steps need a descriptive `name`.
  - workflow steps should have the following format:
    ```
    - name: Step Name
      id: step-name
      # http://github.com/owner/repo/releases
      uses: owner/repo
      ...
    ```
    OR
    ```
    - name: Step Name
      id: step-name
      run: ${{ github.workspace }}/.github/workflows/scripts/script-name.sh
      ...
    ```
  Update any workflow steps necessary to meet this guideline.
- Shell attributes need to be formatted in a way that a human can read and understand them effectively.
  - Bad:
    ```yaml
      shell: su suse bash -c "source /home/suse/.profile;nix develop --ignore-environment --extra-experimental-features nix-command --extra-experimental-features flakes --keep HOME --keep SSH_AUTH_SOCK --keep IDENTIFIER --keep GITHUB_TOKEN --keep GITHUB_OWNER --keep ZONE --keep AWS_ROLE --keep AWS_REGION --keep AWS_DEFAULT_REGION --keep AWS_ACCESS_KEY_ID --keep AWS_SECRET_ACCESS_KEY --keep AWS_SESSION_TOKEN --keep UPDATECLI_GPGTOKEN --keep UPDATECLI_GITHUB_TOKEN --keep UPDATECLI_GITHUB_ACTOR --keep GPG_SIGNING_KEY --keep NIX_SSL_CERT_FILE --keep NIX_ENV_LOADED --keep TERM --command bash -e {0}"
    ```
  - Better:
    ```yaml
        shell: >-
          su suse bash -c "source /home/suse/.profile; \
          nix develop
            --ignore-environment
            --extra-experimental-features nix-command
            --extra-experimental-features flakes
            --keep HOME
            --keep SSH_AUTH_SOCK
            --keep IDENTIFIER
            --keep GITHUB_TOKEN
            --keep GITHUB_OWNER
            --keep ZONE
            --keep AWS_ROLE
            --keep AWS_REGION
            --keep AWS_DEFAULT_REGION
            --keep AWS_ACCESS_KEY_ID
            --keep AWS_SECRET_ACCESS_KEY
            --keep AWS_SESSION_TOKEN
            --keep UPDATECLI_GPGTOKEN
            --keep UPDATECLI_GITHUB_TOKEN
            --keep UPDATECLI_GITHUB_ACTOR
            --keep GPG_SIGNING_KEY
            --keep NIX_SSL_CERT_FILE
            --keep NIX_ENV_LOADED
            --keep TERM
            --command bash -e {0}"
    ```
