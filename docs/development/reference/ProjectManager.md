# Project Manager & Map-Reduce Code Review Specifications

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

This component specification details the persona, orchestration sequences, safety boundaries, and verification criteria governing our automated pre-commit Map-Reduce Review pipeline coordinated by our secure JavaScript script `code-review.js`.

---

## Abstract

To maintain absolute codebase security, logic correctness, and compliance with our Diátaxis-structured Reference coding standards, this repository implements an automated, parallelized Map-Reduce Code Review pipeline.

Instead of relying on monolithic prompts that suffer from context-inflation and leniency, we leverage a native hybrid programmatic/agent ecosystem:

1. **The Programmatic Orchestrator (`code-review.js`):** A secure, local Node.js script located at `agent-scripts/code-review.js` that coordinates the overall execution flow, runs git checks, maps file diffs, and compiles the final report.
2. **The Heads-Down Coder (`@heads_down_coder`):** A rule-stickler worker agent that audits individual file diffs line-by-line for flaws, weaknesses, and inelegant wording (Map Phase).
3. **The Data Scientist (`@data_scientist`):** A precise lead aggregator that de-duplicates, categorizes, and compiles raw findings into an unbiased, problem-only 4-Pass Programmatic Review/Testing Gate (Gate 2) report (Reduce Phase).

This hybrid approach completely avoids the nested subagent crash issue because the orchestration is handled programmatically in local node space rather than in the LLM agent loop itself.

---

## 🧭 Map-Reduce Execution Sequence

When the primary development session invokes the Review Phase (Gate 2) by executing `agent-scripts/code-review.js`:

```text
  [ Developer Session / Agentic Loop ]
           │
           ▼ (executes)
     [ node agent-scripts/code-review.js ] ──► (Step 1: Runs git diff HEAD)
           │
           ├─► (Step 2: Map Phase - Invokes @heads_down_coder per file diff via CLI)
           │    ├─► @heads_down_coder [Go.md] ──────► Notes
           │    ├─► @heads_down_coder [JavaScript.md] ──► Notes
           │    └─► @heads_down_coder [ShellScripts.md] ──► Notes
           │
           ▼
     [ code-review.js ] ──► (Step 3: Reduce Phase - Invokes @data_scientist with compiled notes via CLI)
           │
           ▼
     @data_scientist ──► Groups, de-duplicates, sorts HIGH to LOW, and compiles final report
           │
           ▼ (Step 4: Returns final 4-Pass report)
  [ Gating Hooks ] ──► (Programmatically validates and signs review-approval.json)
```

### Step 1: Identify Changed Files

The `code-review.js` executes `git diff HEAD --name-only` to isolate modified files, aggressively skipping binary lockfiles and assets to conserve context.

### Step 2: Map Phase (Adversarial Auditing)

For each file, the `code-review.js` extracts its specific diff (`git diff HEAD -- [file]`) and triggers `@heads_down_coder` using the native Gemini CLI command line interface.

- The `@heads_down_coder` acts as an un-compromising, rule-stickler reviewer. It treats execution like a chess puzzle, noting every logic, syntax, documentation, or security flaw, and outputs raw, line-numbered jottings without proposing solutions.

### Step 3: Reduce Phase (Data-Driven Aggregation)

The `code-review.js` compiles all raw coder findings and invokes `@data_scientist` using the Gemini CLI command line interface.

- The `@data_scientist` de-duplicates matching comments, categorizes larger systemic patterns, and sorts concerns strictly by severity:
  - **Inconsequential (LOW):** Formatting, spellings, cosmetic rewordings.
  - **Consequential (MED/HIGH):** Logic, execution, correctness, and security.
    - **HIGH:** Main operation failures or major security holes.
    - **MED:** Edge cases, resource safety, and minor bugs.
- **Absolute Objectivity:** It produces a clinical, problem-only report (strictly no solution bias).

### Step 4: Final Output and Signature Gating

The `code-review.js` validates the report output format and required keywords. Upon success, it programmatically/cryptographically signs the review gate, writing `review-approval.json` to disk, setting the workspace phase to `commit` in `phase-state.json`, and unlocking the Commit Phase (Gate 3).

---

## 🔒 Hardened Sandbox & Security Boundaries

- **Read-Only Enforcements:** The subagents are completely stripped of write capabilities, restricting their toolsets strictly to `[read_file]`, `[glob]`, and `[run_shell_command]`. They cannot modify code or manually write signatures.
- **Zero Hook Interference:** Because the orchestrator and its subagents are called natively within the active session, they execute in-process. This prevents the spawning of new shell sessions, bypassing all redundant workspace startup hooks natively!
- **Safe Command Excursions:** When running `git diff`, `code-review.js` uses argv arrays via `execFileSync`, preventing shell injection vulnerabilities.
