# Developer Documentation Changelog

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

## Abstract

This document tracks all updates, refactors, and structural changes made to the developer architecture blueprints and repository specifications under the `docs/development/` directory.

---

## [Unreleased] - 2026-08-19

### Refactored

- **Consolidated Topics & Directories**: Grouped all process guidelines, workflows, and formatting rules under a unified directory structure to maximize cohesive discoverability and comply strictly with standard paradigms.
- **Relocated Workflows**: Moved all repository-specific automation workflows from `.gemini/workflows/` to `docs/development/how-to/` or `docs/development/explanation/` respectively:
  - `development-process.md` -> `how-to/DevelopmentProcess.md`
  - `resolve-pr-reviews.md` -> `how-to/PRReviewResolution.md`
  - `troubleshoot-workflows.md` -> `how-to/WorkflowTroubleshooting.md`
- **Relocated Formatting Styles**: Moved formatting style guidelines from `.gemini/output-styles/` to `docs/development/explanation/`:
  - `strict.md` -> `explanation/OutputStyleStrict.md`
  - `conversational.md` -> `explanation/OutputStyleConversational.md`
- **Established Coding Standards Topic**: Created a new top-level **Coding Standards** topic overview (`reference/CodingStandards.md`) and relocated all standards and language instructions from `.gemini/rules/` to `docs/development/reference/`:
  - `go.instructions.md` -> `reference/Go.md`
  - `terraform.instructions.md` -> `reference/Terraform.md`
  - `workflows.instructions.md` -> `reference/Workflows.md`
  - `github-script.instructions.md` -> `reference/GitHubScript.md`
  - `shell-scripts.instructions.md` -> `reference/ShellScripts.md`
  - `github-copilot-review.instructions.md` -> `reference/GitHubCopilotReview.md`
  - `documentation.instructions.md` -> `reference/Documentation.md`
  - `blueprints.instructions.md` -> `reference/Blueprints.md`
  - `standards.md` -> Eliminated by absorbing global linting/spelling/formatting rules into `reference/CodingStandards.md` and standard testing targets into `how-to/Testing.md`.
- **Pruned Unused Folders**: Completely deleted `.gemini/workflows/`, `.gemini/output-styles/`, and `.gemini/rules/` from the automation suite, restoring `.gemini/` as a generic portable template.
- **Retired `PLAN_LOG.md`**: Removed the redundant historical plan logs.

### Added

- **Official Gemini layout reference**: Created `.gemini/README.md` defining Google's standard user-level vs project-level folder structure.
- **Changelog**: Added this `CHANGELOG.md` file specifically tracking developer documentation under `docs/development/reference/`.
