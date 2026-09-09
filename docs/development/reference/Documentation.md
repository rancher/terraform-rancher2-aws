---
applyTo: '**/*.md'
---

# Documentation & Architectural Blueprint Standards (Reference Dictionary)

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

This document is a dry, structured reference index of Markdown formatting, spellchecking, Diátaxis layouts, and architectural alignment rules.

---

## 1. Syntax, Formatting & Linter Compliance

- **Rule: Mandatory Local Spellchecking (`cspell`)**
  - **Constraint:** All written documentation, code comments, and configuration descriptions must be free of typographical errors and slang.
  - **Constraint:** Technical abbreviations, repository names, or domain-specific terminology must be added strictly to `custom_words.txt` rather than ignored inline.
- **Rule: Standard Sequential Markdown Nesting**
  - **Constraint:** Headers must follow sequential nesting (`#`, `##`, `###`, etc.). Skipping header levels is strictly banned.
- **Rule: Consistent Capitalization and Punctuation**
  - **Constraint:** All headings must use title case or sentence case consistently. Code comment blocks must begin with capital letters and end with proper punctuation, behaving as standard technical English.

## 2. Diátaxis Documentation Framework

All user-facing and technical manuals located under `docs/` must organize knowledge strictly around the four **Diátaxis archetypes**:

- **Rule: Tutorials (Learning-Oriented)**
  - **Constraint:** Guide a beginner through a series of steps to achieve a basic setup. They focus on learning, not executing production tasks.
- **Rule: How-To Guides (Goal-Oriented)**
  - **Constraint:** Provide specific, sequential instructions for a user who already has a concrete goal in mind (e.g., "How to register a custom subagent").
- **Rule: Reference Material (Information-Oriented)**
  - **Constraint:** Provide dry, clinical, and exhaustive technical facts, API specs, schemas, and parameter options (e.g., policy schemas or CLI commands).
- **Rule: Explanation (Understanding-Oriented)**
  - **Constraint:** Provide high-level, reflective background context, architecture narratives, design trade-offs, and "why" explanations (e.g., Zero-Trust design decisions).

## 3. Architectural Blueprints & Planning Documents

- **Rule: Standard Topic Overview Layout**
  - **Constraint:** Overarching domain documents that map a major system area (such as `ReleaseProcess`, `Testing`, or `AgenticFramework`) must reside directly under `docs/development/` and contain an abstract section named `## Abstract` and links to sub-components.
- **Rule: Standard Component Specification Layout**
  - **Constraint:** Technical specifications for individual sub-components must contain a clear, technical abstract section named `## Abstract` explaining the component's goals and execution rules.
- **Rule: Strictly Declarative Blueprints**
  - **Constraint:** Blueprints must describe the system's _current, actual state_. Writing transient task checklists, future work "TODO" blocks, past changelogs, or historic milestone timelines inside blueprints is strictly banned. Keep them declarative.

## 4. Quality Gates & Framework Alignment (CRITICAL)

To prevent documentation drift and maintain perfect alignment with our programmatic enforcer hooks, all architectural manuals MUST accurately describe the system's exact Gated Lifecycle:

- **Rule: Strict 3-Gate Architecture**
  - **Constraint:** Documentation must state that there are exactly **3 Gates** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). State that 2 of these gates are user-facing (Planning and Commit).
- **Rule: Strict 4-Phase Lifecycle**
  - **Constraint:** Documentation must state that there is a **Gated 4-Phase Lifecycle** consisting of exactly these phases: `Plan`, `Implement`, `Review`, `Commit`.
- **Rule: Prohibited Inconsistencies**
  - **Constraint:** Any reference to a "4-gate", "5-gate", "7-phase", or "5-hook" architecture, or any other incorrect numbers of gates/phases, is strictly prohibited and must be flagged as a high-severity documentation inconsistency.
    Refactored code: N/A (Standard is declarative)
