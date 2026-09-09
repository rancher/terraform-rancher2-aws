---
applyTo: '**/*.go'
---

# Go (Golang) Coding Standards (Reference Dictionary)

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

## Abstract

This document defines the dry, structured conceptual reference of **Go (Golang) Coding Standards (Reference Dictionary)** within this repository. It establishes the clinical parameters, design rules, and operational constraints for this system area, ensuring standard-compliant environment initialization and developer safety.

This document is a dry, structured reference index of Go syntax, security, concurrency, and architecture rules.

---

## 1. Syntax, Formatting & Linter Compliance

- **Rule: Linter Compliance (`golangci-lint`)**
  - **Constraint:** All Go code must pass the local `golangci-lint` configuration with zero warnings or violations.
- **Rule: No Commented-Out Code**
  - **Constraint:** Commented-out code blocks must be deleted from active source files. Use Git history for retrieval.
- **Rule: Standard Go Formatting (`gofmt`, `goimports`)**
  - **Constraint:** All files must be formatted with `gofmt -s` and imports must be grouped/ordered using `goimports`.
- **Rule: No Package-Level `init()` Functions**
  - **Constraint:** Package-level `init()` functions are strictly banned.
  - **Exception:** Only allowed when registering drivers or immutable compiler guards.

## 2. Error Handling & Logic Resilience

- **Rule: Check Errors Immediately**
  - **Constraint:** Never ignore or discard return errors (using `_` or omitting checks).
  - **Bad:** `local_func(param) // ignoring error`
  - **Good:** `err := local_func(param); if err != nil { ... }`
- **Rule: Sentinel Error Wrapping (`%w`)**
  - **Constraint:** Wrap bubbled errors using the `%w` verb to maintain the original call chain.
  - **Bad:** `fmt.Errorf("error reading config: %s", err)`
  - **Good:** `fmt.Errorf("error reading config: %w", err)`
- **Rule: Happy-Path Left-Alignment (Early Returns)**
  - **Constraint:** Return immediately on error conditions to avoid deeply nested, hard-to-read conditional blocks.
- **Rule: Banned `panic()` / `log.Fatal()` Invocations**
  - **Constraint:** Banned in all normal control flows and validation sequences.
  - **Exception:** Allowed only for unrecoverable startup initialization failures.

## 3. Concurrency, Safety & Execution (Vulnerability Prevention)

- **Rule: Explicit Context Propagation**
  - **Constraint:** The first parameter of any blocking, network, disk, or DB function MUST be `ctx context.Context`.
  - **Signature:** `func Method(ctx context.Context, id string) error`
- **Rule: No Struct-Bound Contexts**
  - **Constraint:** Contexts must flow dynamically down the call stack. Do not store contexts inside structs or configurations.
- **Rule: Explicit Goroutine Lifecycle Cleanup**
  - **Constraint:** Every goroutine launched (`go func()`) must be tracked using `sync.WaitGroup`, `golang.org/x/sync/errgroup`, or context cancellation (`ctx.Done()`) to prevent goroutine leaks.
- **Rule: Channel Closure Safety**
  - **Constraint:** Channels must only be closed by the sender goroutine. Writing to a closed channel is strictly forbidden.
- **Rule: Cryptographically Secure Random Generation**
  - **Constraint:** For GPG signing, tokens, challenges, and keys, you MUST use `crypto/rand`. `math/rand` is strictly banned.
- **Rule: Command Injection Mitigation (`os/exec`)**
  - **Constraint:** Do not construct CLI arguments using string formatting or variable interpolation. Pass separate strings via argv arrays.
  - **Bad:** `exec.Command("git", fmt.Sprintf("diff %s", branch))`
  - **Good:** `exec.CommandContext(ctx, "git", "diff", branch)`

## 4. Architecture, State, Testing & Gates

- **Rule: Interface-Driven Dependency Injection**
  - **Constraint:** Inject package dependencies as thin, descriptive interfaces (e.g., `io.Writer`) rather than concrete structs to support isolated mocking.
- **Rule: No Package-Level Mutable Variables (`var`)**
  - **Constraint:** Global mutable package state is banned. Encapsulate state inside instantiated structs passed down via dependency injection.
- **Rule: No Naked Returns in Long Functions**
  - **Constraint:** Functions longer than 5 lines must explicitly name their return variables in the `return` statement.
- **Rule: Stand-Alone Integration Test Module**
  - **Constraint:** The `./test` directory must contain its own independent Go module (`test/go.mod`) to separate testing dependencies.
- **Rule: Seeded Local Plugin Cache**
  - **Constraint:** Acceptance tests must use a localized Terraform plugin cache. The cache must be seeded offline from the global cache established during runner boot (`run_tests.sh`) to prevent rate limits.
