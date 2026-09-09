# Agentic Framework: Boilerplate Sync Script

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

## Abstract

To maintain cross-project consistency across multiple repositories without the heavy administrative overhead of Git submodules, the Agentic Framework implements a lightweight, **manifest-driven asset synchronization script** (`sync-boilerplate.sh`). This tool allows developers and agents to dynamically track, compare, pull, and push common configuration files and directories (such as linters, CI/CD scripts, enforcer tools, and agent setups) to and from a centralized master template repository, keeping all systems fully aligned.

---

## Technical Specification

### 1. The Sync Manifest (`.boilerplate-sync.json`)

Each child repository declares its tracking files, directories, and local destinations inside a `.boilerplate-sync.json` configuration file located in the repository's root directory:

```json
{
  "files": [
    { "local": ".gemini", "remote": ".gemini" },
    { "local": "docs/development", "remote": "docs/development" },
    { "local": "agent-scripts", "remote": "agent-scripts" }
  ]
}
```

### 2. Operational Logic & Sequence

The sync utility `agent-scripts/sync-boilerplate.sh` executes the following sequence to compare or copy assets:

```text
[Local Repo]                     [System OS / TMP]                     [Remote Repo]
     │                                   │                                   │
     │ ── 1. Read Manifest JSON ───────► │                                   │
     │                                   │ ── 2. git clone --depth 1 ──────► │
     │                                   │ ◄── 3. Shallow Local Checkout ─── │
     │                                   │                                   │
     │ ◄── 4. Execute 'diff' or 'cp' ─── │                                   │
     │                                   │                                   │
     │                                   │ ── 5. Trap: rm -rf /tmp/clone ──► │
```

Note: The sequence diagram is simplified and omits the --no-checkout flag for readability.

1. **Manifest Parsing**: Reads and validates the JSON `.files` array using `jq`.
2. **Hermetic Sandbox Prep**: Establishes a temporary workspace directory under `/tmp/boilerplate-sync-XXXXXX` using `mktemp -d`.
3. **Repository Fetching**: Clones the remote master repository off the default branch using a no-checkout clone (`git clone --depth 1 --no-checkout <repo_url> <tmp_dir>`). This prevents checking out files in the working tree initially, checking out strictly the tracked files and directories to keep the local working tree footprint lightweight. The template repository URL must be provided dynamically at runtime (see below).
4. **Operations Modes**:
   - **Diff Mode (`--diff`)**: Runs recursive `diff -ru` for directories or standard `diff -u` between the local assets and their remote template counterparts.
   - **Sync/Pull Mode (`--pull`)**: Overwrites the local assets by copying the template files or directories into place, creating any missing parent directories natively and cleaning up old copies with `rm -rf`.
   - **Sync/Push Mode (`--push`)**: Copies local files and directories that differ back to the remote template clone, switches to a new unique feature branch, commits them conventionally, pushes the branch to origin, and generates a Pull Request against the target repository's default branch using the `gh` CLI.
5. **Secure Workspace Cleanup**: Registers an exit trap (`trap 'cleanup' EXIT`) that mathematically guarantees the temporary directories are fully destroyed on exit, preventing `/tmp` clutter or memory leak vectors.

---

## Standing Implementation Decisions

1. **Pull Request-Based Workflow on Push**: Rather than pushing updates directly to the default branch of the master repository, the utility securely pushes to a unique feature branch and uses the GitHub CLI (`gh`) to open a Pull Request. This prevents accidental direct-push modifications and enforces a clean review/approval process.
2. **Standard Commits on Push**: When pushing updates back to the centralized template repository, changes are always committed using standard, non-bumping conventional commits (e.g. `sync: update boilerplate from <repo>`) to maintain pristine release-please semantics in the master repository.
3. **No-Checkout Optimization**: `git clone` always uses `--no-checkout` to avoid pulling unnecessary files, checking out only the exact files and directories mapped in `.boilerplate-sync.json` for read operations.
4. **Dynamic Repository URL Parsing**: To prevent hardcoding a specific repository URL inside version-controlled configuration, the utility strictly requires the target central repository URL to be explicitly provided at runtime using the `-r/--repo` option or via the `CENTRAL_FILE_REPO` environment variable. It throws a fatal error if neither is supplied.

---

## Mitigating Sync-Write Overwrite Collisions

Because the boilerplate synchronization pulls configuration files (such as `package.json`, `.prettierrc`, and linter settings) directly from a centralized repository and overwrites the local targets in `--pull` mode, there is a risk of losing repository-specific customizations.

To mitigate **Sync-Write Overwrite Collisions**, follow these strict developmental standards:

1. **Always Diff Before Pulling**: Run `sync-boilerplate.js --diff` first. Review the precise comparative output to identify if any custom local modifications will be overwritten.
2. **Commit or Stash Workspace Changes**: Never pull boilerplate changes into a dirty workspace. Ensure all local-only modifications are fully committed or stashed before running a sync pull.
3. **Isolate Customizations**:
   - For configuration files like `package.json`, maintain standard ecosystem packages in the synced boilerplate while placing repository-specific dependencies and packages under isolated, non-synced secondary blocks, or utilize non-destructive merging scripts if custom packages are required.
   - For linters or formatters, define repository-specific exclusions in local-only ignore lists (like `.gitignore` or local configuration overrides) rather than editing the globally synced template files directly.
