---
applyTo: '**/*.tf'
---

# Terraform Coding Standards (Reference Dictionary)

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

## Abstract

This document defines the dry, structured reference index of Terraform variable validations, lifecycles, and state safety rules. It establishes the clinical syntax and design requirements for all Terraform configurations within this repository, ensuring standard-compliant environment initialization and resource safety.

---

## 1. Syntax, Formatting & Linter Compliance

- **Rule: Formatting Compliance (`terraform fmt`)**
  - **Constraint:** All `.tf` files must comply strictly with standard `terraform fmt` indentation, spacing, and block alignment rules.
- **Rule: Lowercase Snake Case Identifiers**
  - **Constraint:** All block identifiers, resource names, data source names, variable names, module names, and output names MUST use lowercase letters, digits, and underscores only (`snake_case`). Never use uppercase letters or hyphens (`-`) in block labels.
  - **Bad:** `resource "local_file" "Local-File-01" { ... }`
  - **Good:** `resource "local_file" "local_file_01" { ... }`
- **Rule: Static Linter Compliance (`tflint`)**
  - **Constraint:** All directories must pass local `tflint` static analysis scans with zero warnings or violations.

## 2. Declarative Logic & Lifecycle Management

- **Rule: Stability via `for_each` over `count`**
  - **Constraint:** Prefer using `for_each` over `count` when creating multiple resources from lists or maps. `count` relies on list index numbers, causing severe index-shifting and redundant resource destruction/creation cycles if items are deleted from the middle of the list.
- **Rule: Basic Variable Validations**
  - **Constraint:** Use `validation` blocks on variables for input-level correctness (such as verifying regex patterns, CIDR block syntax, or string options) at the earliest possible stage.
- **Rule: Complex Post-Apply Validations (Check Blocks)**
  - **Constraint:** Use `check` blocks for post-apply functional validations, especially assertions that involve comparing inputs or outputs across multiple separate variables or resources.
- **Rule: Complex Execution Block Preconditions**
  - **Constraint:** Use `terraform_data` resource preconditions for complex structural assertions that cannot be evaluated in standard `check` blocks, ensuring execution halts before destructive apply operations occur.
- **Rule: Scoped Explicit Dependencies (`depends_on`)**
  - **Constraint:** Avoid using `depends_on` unless implicit dependencies (e.g. referencing `local_file.foo.id`) are structurally impossible. If `depends_on` is required, document precisely why.

## 3. Security, Hardening & State Safety (Vulnerability Prevention)

- **Rule: Redact Private Output Values (`sensitive = true`)**
  - **Constraint:** Any variable or output containing credentials, TLS private keys, API keys, passwords, or personal data MUST be explicitly marked with `sensitive = true` to prevent their exposure in plaintext terminal outputs or GHA UI logs.
- **Rule: No Hardcoded Credentials**
  - **Constraint:** Under no circumstances should secrets or tokens be hardcoded inside any `.tf` file. Manage secrets through secure variables, vault data sources, or environment-injected context.
- **Rule: Static Security Scans (`tfsec` / `trivy`)**
  - **Constraint:** All configurations must pass static security scans (`tfsec` or `trivy`) to ensure compliance with infrastructure hardening baselines (e.g. blocked public ingress CIDRs, unencrypted S3 buckets, or missing transit encryption).

## 4. Architecture, Modularization & Testing

- **Rule: Strict Variable Type Enforcements**
  - **Constraint:** Never declare variables with `type = any`. Always declare explicit, tightly constrained schemas (e.g., `type = list(string)` or `type = map(object({ ... }))`) to catch configuration errors during plan phase.
- **Rule: Separation of Concerns (Module Layout)**
  - **Constraint:** All directories containing Terraform configurations MUST separate block types into discrete, standardized files:
    - `main.tf` (resources, local variables, and data sources)
    - `variables.tf` (all variable declarations with descriptions)
    - `outputs.tf` (all output values with descriptions and sensitivity markings)
    - `versions.tf` (required provider version and terraform block declarations)
- **Rule: Mandatory Descriptive Comments**
  - **Constraint:** Every variable and output declaration MUST contain a meaningful, grammatically correct `description` string explaining its purpose, assisting both developers and automated document generators (like `terraform-docs`).
