# Developer Documentation Center

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

## Abstract

This document defines the dry, structured conceptual reference of **Developer Documentation Center** within this repository. It establishes the clinical parameters, design rules, and operational constraints for this system area, ensuring standard-compliant environment initialization and developer safety.

Welcome to the `terraform-provider-file` developer documentation center. Our library is structured strictly around the **Diátaxis framework**, which separates documentation into four distinct conceptual archetypes (Tutorials, How-To Guides, Reference, and Explanation).

By organizing our documentation this way, we keep it highly accessible and contextual for both human developers and autonomous AI subagents.

---

## 🧭 Diátaxis Table of Contents

### 1. 🎓 Tutorials (Learning-Oriented)

Gentle, beginner-focused steps designed to help you set up your machine and complete your first local exercises:

- **[Getting Started](./tutorials/GettingStarted.md):** Learn how to clone the repo, load the Nix shell, build the provider, and run a basic unit test.

### 2. 📋 How-To Guides (Goal-Oriented)

Practical, step-by-step procedural guides designed to help you accomplish specific development goals:

- **[Running Tests & Linters](./how-to/Testing.md):** Procedural steps for formatting all code files, executing linters (`golangci-lint`, `shellcheck`, `cspell`), and running our acceptance testing suites.
- **[Executing Releases](./how-to/ReleaseProcess.md):** Procedural checklist for configuring GPG keys, writing conventional commit PR titles, and merging Release PRs to publish signed production assets.

### 3. 🧠 Explanation (Understanding-Oriented)

High-level, concept-oriented narratives explaining "why" our architectures are designed the way they are:

- **[Secure Agentic Framework](./explanation/AgenticFramework.md):** Background context on our zero-bypass sandbox, Apple Secure Enclave Touch ID biometric gating, and the Gated 4-Phase Lifecycle.
- **[Automated Branch Merging](./explanation/AutoMerging.md):** Architectural explanation of our event-driven verification script pipeline, Vault token retrievals, and squash-merging enforcers.
- **[Release Pipeline Lifecycle](./explanation/ReleasePipeline.md):** Concept tracing of our automated versioning triggers, SemVer guards, and GoReleaser compiler workflows.

### 4. 📚 Reference Material (Information-Oriented)

Dry, clinical, and exhaustive technical indices of coding standards, linter rules, syntax constraints, and project history:

- **[Coding Standards Reference Index](./reference/CodingStandards.md):** The primary index of all repository standards.
  - **[Go Standards](./reference/Go.md):** Go linter configurations, error-wrapping, context propagation, and plugin caches.
  - **[Terraform Standards](./reference/Terraform.md):** Resource snake_case naming style, variable validations, sensitive redactions, and module separation rules.
  - **[JavaScript Standards](./reference/JavaScript.md):** Unified ESM rules, empty catch block bans, pagination, and command injection safeguards.
  - **[Shell Scripts](./reference/ShellScripts.md):** Bash fail-fast parameters, shebangs, double brackets, and Makefile actions.
  - **[Workflows](./reference/Workflows.md):** GHA permissions, SHA action pinning, and allowlist namespaces.
  - **[Documentation](./reference/Documentation.md):** Markdown layout structures, Diátaxis specifications, and `cspell` spellcheck exclusions.
- **[Changelog](./reference/CHANGELOG.md):** Historical log of all changes and structural refactors applied to this documentation library.
