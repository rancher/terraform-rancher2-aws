# Agent Scripts Directory Architecture

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

## Abstract

This document defines the dry, structured conceptual reference of **Agent Scripts Directory Architecture** within this repository. It establishes the clinical parameters, design rules, and operational constraints for this system area, ensuring standard-compliant environment initialization and developer safety.

This reference document explains the architectural levels, directory structure, and design principles behind the scripts located within the `agent-scripts/` directory.

---

## Architectural Levels

The codebase implements a strict three-tier hierarchy for automated operations, lifecycle gating, and subagent orchestration:

```text
agent-scripts/
├── lib/                      # Level 1: Library Functions (Low-Level / Reusable Utilities)
│   ├── approval.js
│   ├── file.js
│   └── git.js
├── tools/                    # Level 2: Tools (CLI Wrappers & Multi-Call Public Façade Entrypoints)
│   ├── approval.js
│   ├── file.js
│   └── git.js
└── code-review.js            # Level 3: Goal-Oriented Scripts & Subagent Orchestrators
```

### 1. Library Functions (`agent-scripts/lib/`)

- **Definition**: Highly reusable, stateless (or well-encapsulated), low-level utility functions.
- **Role**: They interface directly with system resources, execute shell programs (like Git or CI runners), and manage data structures or formatting.
- **Usage constraint**: Library functions should **never** be executed directly by the user or hooks. They are imported only by level-2 tools or level-3 scripts.
- **Example files**:
  - `lib/file.js`: Safe file write/read utility functions.
  - `lib/git.js`: Formulates raw git commands, parses diffs, and inspects status.
  - `lib/approval.js`: Performs cryptographic signing and verification.

### 2. Tools (`agent-scripts/tools/`)

- **Definition**: Executable command-line interfaces (CLIs) that map directly to business logic domain boundaries (matching the library counterparts).
- **Role**: They expose and wrap library functions through standard argument parsing (e.g., Node's `util.parseArgs`) to make them executable within Gated Lifecycle Hooks (e.g., `.gemini/hooks/`). Crucially, they act as the official **façade / entrypoint** to their corresponding libraries, re-exporting the library functions.
- **Usage constraint**: Tools should primarily act as bridges—exposing library capabilities via standard CLI inputs. They can be safely imported and run by hooks and other orchestrating scripts. **All scripts at the root level must import through Level-2 Tools, not directly from Level-1 Libraries.**
- **Example files**:
  - `tools/approval.js`: CLI tool and module entrypoint to handle cryptographic signature approvals.
  - `tools/plan.js`: CLI tool and module entrypoint to create, update, or validate plans.

### 3. Scripts (`agent-scripts/`)

- **Definition**: Goal-oriented automations and higher-level orchestrators.
- **Role**: They execute a sequence of tools and subagents to accomplish complex, cross-cutting tasks (such as a full review loop, checklist generation, or testing pipeline).
- **Usage constraint**: These are top-level scripts meant to be directly executed by the user or automated workflows (e.g., cron jobs, CI pipelines).
- **Example files**:
  - `code-review.js`: Core orchestrator of the map-reduce subagent code auditing loop.
  - `exercise-agents.js`: System validation script that sequentially invokes each Gemini model in its own isolated temporary sandbox.
  - `cleanup-data.js`: System utility script to purge stale temporary directories.

---

## Design Principles

1. **Strict Isolation**: Do not place high-level orchestrator logic or execution triggers directly inside `/lib`. Keep lib files clean of terminal output-formatting, argument-parsing, and prompt orchestration whenever possible.
2. **Tool-as-Façade Entrypoint**: Level-2 Tools (inside `tools/`) are the official entrypoints to Level-1 Libraries (inside `lib/`). Tools must import and re-export the underlying library functions, acting as a multi-call façade.
3. **Explicit Import Paths**:
   - `lib/*` files can only import other `lib/*` files using relative sibling imports (e.g. `import { ... } from './file.js'`).
   - `tools/*` files import from and expose `../lib/*`.
   - `scripts/*` (at the root of `agent-scripts/`) must **never** import from `./lib/*`. They must exclusively import from `./tools/*` (e.g. `import { ... } from './tools/file.js'`).
   - **Hook Scripts** (under `.gemini/hooks/`) must **never** import from `agent-scripts/lib/` directly. They must exclusively import from `agent-scripts/tools/`.

4. **No Direct Executable Usage of Libs**: Level-1 library files should not have `if (process.argv[1] === ...)` block execution logic. Command-line execution support must live exclusively in Level-2 Tools or Level-3 Scripts.
