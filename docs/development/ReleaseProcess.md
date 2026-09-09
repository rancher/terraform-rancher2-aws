# Release Process & Lifecycle Map

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

## Abstract

This document defines the dry, structured process map of the **Release Process & Lifecycle** within this repository. It establishes the clinical parameters, design rules, and operational constraints for this system area, ensuring standard-compliant environment initialization and developer safety.

This document is a comprehensive, declarative Reference and Process Map describing the automated release pipeline, cryptographic signing architecture, and versioning lifecycle.

---

## Phase 1: Local GPG Signing Key Configuration

All commits that undergo gating checks must be cryptographically signed by your personal GPG key. The local setup process is outlined as follows:

1. **Verify your key exists:**

   ```bash
   gpg --list-secret-keys --keyid-format=long
   ```

2. **Configure Git to use your GPG key:**

   ```bash
   git config --global user.signingkey <YOUR_KEY_ID>
   git config --global commit.gpgsign true
   ```

3. **Register your GPG key in your local SSH agent if utilizing SSH-based signing keys:**
   Refer to our **[Documentation Standards](reference/Documentation.md)** to verify private/public key completeness.

## Phase 2: Change Proposal via Conventional Commits

Version calculations are completely automated. To propose a version increment, you must format your Pull Request squash-merge titles according to **Conventional Commits**:

1. **Bug Fixes (Minor patch release):** Format as `fix: description` (e.g. `fix: handle null values in directory client`).
2. **New Features (Minor feature release):** Format as `feat: description` (e.g. `feat: add local snapshot caching`).
3. **Breaking Changes (Major breaking release):** Append `!` or declare `BREAKING CHANGE:` in the commit footers (e.g. `feat!: change default directory paths`).

## Phase 3: Review and Monitoring of Automated Release PRs

Once your PR lands on the `main` branch:

1. **Trigger Calculation:** The `release-please` GHA action executes. It automatically scans your squash-merge commit title and updates the running Release PR (e.g. `chore(main): release v1.2.3`).
2. **Acceptance Testing:** The Release PR automatically triggers OpenID Connect (OIDC) integration tests inside a Nix shell, compiling release candidates (e.g. `v1.2.3-rc.0`) to verify binary execution.

## Phase 4: Release PR Merging on GitHub

When you are ready to publish the stable production assets:

1. Navigate to your repository's Pull Requests page on GitHub.
2. Locate the Release PR titled `chore(main): release v1.x.y`.
3. Verify the auto-generated `CHANGELOG.md` updates.
4. **Approve and Merge** the Release PR.

Once merged, the automated runner will automatically:

- Tag the repository with the exact version (`v1.x.y`).
- Securely extract signing keys from Vault.
- Cross-compile and GPG-sign all binaries using GoReleaser.
- Publish the stable assets natively to the GitHub Release Registry.
