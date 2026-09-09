# Enforce Strict Question Types and Restore Pipeline Logs

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.
>
> **Diátaxis Archetype**: Reference Manual

---

## Abstract

This document defines the architectural specification for enforcing strict, deterministic `yesno` question types for all cryptographic approval requests inside the Gated 4-Phase Lifecycle. This enforces binary, unambiguous choices and guarantees complete traceability of pipeline logs.

---

## Architectural Specifications

### 1. Mandatory `yesno` Question Type

All cryptographic approvals (for both `plan approval` and `commit approval` intents) MUST utilize a strict `yesno` question type:

- This guarantees that the developer receives a binary Yes/No choice rather than a free-text input box.
- The validation hook `.gemini/hooks/shared.js` immediately blocks any approval request violating this schema.

### 2. Streamlined Approval Parsers

By enforcing the strict `yesno` type globally:

- The approval parsing logic is simplified to checking for a clean, case-insensitive `"yes"` value.
- This eliminates complex, fragile string-matching heuristics.

### 3. Captured Pipeline Logs

When executing automated subprocesses (such as `code-review.js` or commit hooks), the orchestrator captures standard output and standard error byte streams:

- These streams are explicitly logged on completion.
- This ensures full traceability and prevents silent failures.
