# Temporary Plan: Test Suite Refactor

## Phase 1: Module Restructuring & DRYing
- [x] 1. Move `test/tests/go.mod` and `test/tests/go.sum` to `test/go.mod` and `test/go.sum` and change module name to `test`.
- [x] 2. Move test folders (`one`, `dev`, `prod`, `downstream`, `three`, `data`) directly under `test/` instead of `test/tests/`.
- [x] 3. Extract duplicate test setup/teardown logic (directories, keypairs, ssh agent, terraform options) into a reusable fixture package (`test/fixture`).
- [x] 4. Update all test packages to use the new fixture package.
- [x] 5. Update `run_tests.sh` to look in the new `test` module root rather than `test/tests`.

## Phase 1.5: Fix Lint Errors
- [x] Fix `errcheck` errors for `aws.DeleteEC2KeyPairE` in `fixture.go`.
- [x] Fix `staticcheck` errors for redundant `.KeyPair` selectors in all test files.

## Phase 2: Dependency Updates & CI
- [x] 6. Update Go to the latest version (1.26) and update all dependencies in `test/go.mod`.
- [x] 7. Create `update-go-deps.sh` to auto-update Go dependencies.
- [x] 8. Create `.github/workflows/update-go-deps.yaml` to trigger the script and generate a PR.

## Phase 3: Terratest V2 Function Refactoring (aws-sdk-go-v2 prep)
- [x] 9. Refactor `random.UniqueId()` to `random.UniqueID()`.
- [x] 10. Refactor `map[string]interface{}` to `map[string]any`.
- [x] 11. Replace all `terraform.*` methods with their `*Context*` equivalents passing `t.Context()`.
- [x] 12. Replace all `aws.*` methods with their `*Context*` equivalents passing `t.Context()`.
- [x] 13. Replace `ssh.SshAgent*` methods with `ssh.SSHAgent*` and pass `t.Context()` where required.

## Phase 4: Git Package Removal
- [x] 13b. Refactor `client.DescribeKeyPairs(input)` to `client.DescribeKeyPairs(t.Context(), input)` in `fixture.go`.
- [x] 14. Create `test/scripts/get_repo_root.sh` using `git rev-parse --show-toplevel`.
- [x] 15. Replace `git.GetRepoRoot(t)` with `shell.Command` executing the script across all test and utility files.

## Phase 4.5: Fix AWS SDK v2 Types
- [x] Update imports in `fixture.go` to use `aws-sdk-go-v2`.
- [x] Refactor `ec2.Filter` and `ec2.DescribeKeyPairsInput` structs to match v2 signatures.
- [x] Refactor `shell.RunCommandAndGetOutputE` to `shell.RunCommandContextAndGetOutputE`.
- [x] Fix `shell.Command` pointer typecheck errors for `shell.RunCommandContextAndGetOutputE`.

## Phase 5: Plugin Cache Seeding
- [x] 16. Modify fixture creation to ensure the terraform plugin cache for each test is seeded from the global cache in `run_tests.sh`.

## Phase 6: Final Verification
- [ ] 17. Run automated tests to verify compilation and linting via `.golangci.yml`.

## Phase 7: Refactor `run_tests.sh`
- [x] 18. Replace `run_tests.sh` with a function-based script featuring `trap` cleanup, cache priming, and expanded linting.
