# Agentic Framework: Cryptographic Gating & Approvals

> **Blueprint Compliance:** This integration MUST adhere strictly to the **Strict 4-Phase Lifecycle** (Plan, Implement, Review, Commit) and the **Strict 3-Gate Architecture** (Planning Gate (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3)). Of these 3 gates, the Planning Gate and Commit Gate are user-facing. No phase or gate may be bypassed.

## Abstract

To maintain absolute system integrity and prevent unauthorized code modifications in an autonomous programming workspace, the Agentic Framework implements a secure, **cryptographically chained gating pipeline**. This system mathematically guarantees that no code can be committed or pushed without satisfying sequential, hardware-authorized checkpoints: Planning (Gate 1), Programmatic Review/Testing Gate (Gate 2), and Commit Gate (Gate 3).

---

## 🔒 Architectural Rationale: Why We Cryptographically Chain Gates

Traditional CI/CD pipelines and pre-commit checks are highly vulnerable to **TOCTOU (Time-of-Check to Time-of-Use)** attacks and race conditions. An autonomous AI agent could theoretically modify files _after_ passing local tests and reviews, but _before_ executing the final commit, thereby injecting unvetted code into the repository.

To eliminate this vulnerability, our framework enforces a **Strict Cryptographic Chaining Rule**:

1. **The Hash Anchor**: Every stage of the development process is anchored to a unique, live SHA-256 hash of the entire active workspace difference (`git diff HEAD`), termed the `diff_hash`.
2. **Immutable Binding**: When a gating step succeeds, its signature (`plan-approval.json` or `review-approval.json`) is cryptographically bound to that exact `diff_hash` and the active `plan_hash`.
3. **Chained Verification**: Subsequent gates—and ultimately the custom `agent-scripts/commit-push-helper.sh` utility—will unconditionally reject operations if any of the following occur:
   - The files on disk change (which changes the current `diff_hash` and causes an immediate mismatch with the signatures).
   - Any signature is missing or altered.
   - The signatures are generated out of order (e.g., trying to write a Review approval before a Test approval is signed).
4. **Self-Healing Revocation**: If any check fails or if the agent modifies any source file, the enforcer hooks automatically unlink (delete) the downstream signatures, immediately revoking approvals and halting the pipeline.

---

## 🧬 Hardware-Backed 2FA Gating & Threat Model

In a secure, semi-autonomous engineering environment, the ultimate threat is **Agent Autonomy Escalation**: an AI agent fabricating or signing off on its own changes without real developer oversight.

To prevent this, the framework binds the **Planning Gate (Gate 1)** and the final **Commit Gate (Gate 3)** to a cryptographic key. We highly recommend that the user have some form of 2-factor access to their key—whether that is a TOTP, a hardware security key (like a YubiKey), or biometric authorization (like Mac Touch ID). This requires a physical confirmation from the developer to cryptographically sign approvals, ensuring the developer remains the absolute authority over the codebase.

### Cryptographic Decryption Flow

```text
[Gemini CLI]                         [System OS (Enforcer Hook)]                  [Apple Secure Enclave]
     |                                           |                                           |
     | -- 1. Trigger exit_plan_mode --------->   |                                           |
     |                                           | -- 2. Encrypt Token with Public Key --->  |
     |                                           |       (Writes challenge envelope)         |
     |                                           |                                           |
     | <--- 3. Prompt: "Approve?" -------------- |                                           |
     |                                           |                                           |
     | -- 4. Click: [Approve Plan] ------------> |                                           |
     |                                           | -- 5. Execute age decryption ---------->  |
     |                                           |                                           | [2FA / Hardware Prompt]
     |                                           |                                           | <--- Physical Tap / Token Entry
     |                                           | <--- 6. Decrypted Token ----------------- |
     |                                           |                                           |
     | <--- 7. Write plan-approval.json -------- |                                           |
```

1. **Challenge Generation**: The enforcer hook (`04-commit-phase.js --after-ask`) intercepts the approved `ask_user` tool execution. It generates a secure, randomized challenge token and encrypts it using the developer's public GPG/age key (`~/.gemini/age-key.pub`).
2. **Hardware Authorization**: The hook invokes `age` to decrypt the challenge envelope using the private key handle (`~/.gemini/age-key.txt`).
3. **Secure Enclave Interception**: Because the private key handle is securely enrolled in the macOS Keychain and tied to the Secure Enclave, macOS intercepts the request and natively triggers a Touch ID biometric prompt.
4. **Biometric Validation**: If the developer touches the sensor, the Secure Enclave decrypts the token, confirming human presence. The hook then saves the valid `plan-approval.json` or `user-approval.json` signature to disk, unblocking the pipeline.

---

## 🛠️ Step-by-Step age and Touch ID Key Setup Guide

The framework uses the `age` modern encryption utility and `age-plugin-se` (Apple Secure Enclave plugin) to coordinate biometric signatures. Both packages are **natively provided** by our hermetic Nix development shell (`flake.nix`).

### 1. Generate a Standard age Key (Fallback / Linux)

To generate a standard, file-based age key pair (primarily used in non-Darwin environments or as a backup):

```bash
# Generate the key pair and save to the standardized path
age-keygen -o ~/.gemini/age-key.txt

# Extract the public key and save it to the pub file
age-keygen -y ~/.gemini/age-key.txt > ~/.gemini/age-key.pub
```

### 2. Generate an Apple Secure Enclave (Touch ID) age Key (macOS / Darwin)

To generate a hardware-bound private key handle securely stored in your macOS Keychain and tied to Touch ID:

```bash
# Generate a Secure Enclave GPG-compatible age key pair
age-plugin-se -g -o ~/.gemini/age-key.txt

# The public key is printed directly to stdout during generation.
# Copy that public key string (starting with "age1...") and write it to:
echo "age1<your_public_key_string_here>" > ~/.gemini/age-key.pub
```

_Note: This creates a secure private key reference in `age-key.txt` that only the Apple Secure Enclave can decrypt. The actual private key never leaves your physical hardware._

### 3. Generate an Apple Secure Enclave (Touch ID) SSH Key (macOS / Darwin)

Alternatively, you can create a native macOS Touch ID-backed SSH key using the Apple Secure Enclave (`ssh-keychain.dylib`), which can also be utilized for `age` cryptographic gating via SSH integration.

1. **Create the biometric identity in the Secure Enclave:**

   ```bash
   sc_auth create-ctk-identity -l ssh -k p-256-ne -t bio
   ```

2. **Generate the SSH key handle:**

   ```bash
   ssh-keygen -w /usr/lib/ssh-keychain.dylib -K -N ""
   ```

3. **Export the Security Key Provider to your environment:**

   ```bash
   export SSH_SK_PROVIDER=/usr/lib/ssh-keychain.dylib
   echo 'export SSH_SK_PROVIDER=/usr/lib/ssh-keychain.dylib' >> ~/.zprofile
   ```

4. **Add the key to your SSH agent:**

   ```bash
   ssh-add -K -S /usr/lib/ssh-keychain.dylib
   ```

5. **Update your SSH Configuration:**

   Edit your `~/.ssh_config` (or `~/.ssh/config`) to ensure the correct provider is used:

   ```text
   Host *
     IdentityAgent none
     SecurityKeyProvider /usr/lib/ssh-keychain.dylib
   ```

6. **Forward the agent:** Ensure your local VM (e.g., Colima) is configured to forward your SSH agent to your containers.

---

## 🤖 Programmatic Subagent Isolation & AfterTool Hook Integration

While Gates 1 and 3 require human Touch ID biometrics, **Gate 2 (Proactive Review)** is programmatically audited and signed by invoking our specialized Map-Reduce coordinator agent (`project_manager`). Automated tests are enforced programmatically in the pre-review hooks, eliminating the need for a standalone testing subagent.

To guarantee absolute objectivity, the subagents are **fully isolated and sandboxed**:

1. **Read-Only Enforcements**: The subagents (`project_manager`, `heads_down_coder`, and `data_scientist`) are stripped of write capabilities on source files, restricting their toolsets strictly to `[read_file]`, `[glob]`, and read-only shell commands. They cannot modify code or write approvals.
2. **AfterTool Hook Verification**:
   - When the main agent calls `invoke_agent` targeting `project_manager`, the native `AfterTool` hook (`03-review-phase.js --after-invoke`) intercepts the subagent's execution report.
   - It programmatically parses the report to verify that:
     1. All 4 sequential passes (`Pass 1`, `Pass 2`, `Pass 3`, and `Pass 4`) are checked as complete checklist items (e.g. `- [x] Pass 1`).
     2. Exactly 0 findings are reported, verified by the presence of the clean marker `0 comments/findings` or `0 findings`.
   - If the report is successfully verified as complete and clean, the hook **natively and securely** writes `review-approval.json` to disk, signing it with the active `diff_hash` and `plan_hash`.
   - If any pass is unchecked or if findings are recorded, the hook instantly unlinks (deletes) the signatures, revoking any previous approvals.

This architecture prevents the main agent or subagent from manually writing approvals or manipulating results, enforcing a completely deterministic quality gateway.

---

## 🤖 Hook Timeout & Debugging Configuration

To ensure reliable execution during remote Git pushes and GitHub Pull Request creation, the `commit-phase-after-ask-user` hook (`04-commit-phase.js --after-ask`) is configured with a generous timeout of `60000` ms (60 seconds) inside `.gemini/settings.json`.

The hook isolates the automated commit, push, and PR generation steps into distinct, targeted try-catch blocks. This prevents remote connection timeouts or Git authentication errors from being incorrectly reported as Touch ID signature failures, ensuring clear, high-signal debugging logs during execution.

---

## 🤖 Modular Controller & Function Decoupling (Agent-Scripts)

The agentic framework decouples core agent logic (such as signing, verification, and Git helper scripts) from the Gemini-specific CLI integration layer. This ensures code reuse, simplifies testing, and supports multi-agent workspaces.

### 1. Root-Level `agent-scripts/` Directory

Generic, reusable agent scripts—both ESM Node.js modules and POSIX Shell helpers—are organized inside the flat root-level `agent-scripts/` directory. These files do not use Gemini-specific CLI primitives, representing pure agent workflows and operations.

### 2. Controller/Shim Architecture

Files in `.gemini/hooks/` function as thin **controllers**. Their responsibilities are limited to:

- Parsing Gemini-specific tool execution payloads and arguments.
- Invoking the underlying modular scripts under `agent-scripts/` via clean function calls or command execution.
- Formatting and returning standard output protocols to the Gemini CLI.

### 3. Decoupled Subsystems

The core enforcer and automation layers are decoupled into the following dedicated modules:

- **Planning Logic (`agent-scripts/planning.js`)**: Manages blueprint checks and active plan validations.
- **Cryptographic Gating (`agent-scripts/gating.js`)**: Computes workspace `diff_hash` values and verifies Plan, Test, and Review signatures.
- **Sub-Agent Hook Pipeline (`agent-scripts/after-invoke.js`)**: Evaluates review and testing reports upon tool completion, programmatically signing or revoking gate approvals.
- **Hardware/Biometric Signatures (`agent-scripts/after-ask.js`)**: Conducts Touch ID and cryptographic GPG/SSH signature challenges for the Plan and Commit gates.
- **Execution Security (`agent-scripts/security.js`)**: Validates shell commands and paths to prevent command injection or directory bypass.
- **Unified Git Operations (`agent-scripts/git-helpers.js`)**: Consolidates branch switching, remote branch ancestry checks, Conventional GPG-signed commits, and automated PR generation.
- **Automated Quality Verification**: Granular mock-scaffolded unit tests in the `agent-scripts/tests/` directory validate the cryptographic consistency and execution safety of all decoupled helper scripts.

---

## 🛠️ Troubleshooting: Headless TTY GPG/SSH Signing Lockout

### The Problem

When approving Gate 3 (Commit Gate) in the chat via `ask_user`, the enforcer hook executes `commit-push.js` inside an automated, non-interactive node child subprocess. Because this subprocess has no terminal TTY, attempts to prompt the developer for biometric/hardware GPG or SSH authorization (e.g. Touch ID or GPG passphrases) will fail silently, causing `git commit -S -s` to fail.

Upon failure, the enforcer hook's safety trap triggers an immediate rollback—deleting all signatures (`plan-approval.json`, `review-approval.json`) to guarantee zero-trust workspace security.

### The Solution

#### 1. Configure a Graphical Pinentry Program (Recommended)

By default, GPG and SSH agents try to prompt for credentials in the terminal TTY. Configuring a **native GUI pinentry program** completely bypasses the headless TTY requirement by popping up a native macOS/Linux desktop prompt.

- **For macOS/Darwin (using GPG with Touch ID or YubiKey):**
  1. Install `pinentry-mac` using Homebrew:

     ```bash
     brew install pinentry-mac
     ```

  2. Direct `gpg-agent` to use it by editing `~/.gnupg/gpg-agent.conf`:

     ```text
     pinentry-program /opt/homebrew/bin/pinentry-mac
     ```

  3. Restart the GPG agent to load the new settings:

     ```bash
     gpgconf --kill gpg-agent
     ```

- **For Linux (GNOME/KDE/X11):**
  1. Install `pinentry-gnome3` or `pinentry-qt`.
  2. Configure your `~/.gnupg/gpg-agent.conf`:

     ```text
     pinentry-program /usr/bin/pinentry-gnome3
     ```

  3. Restart the GPG agent:

     ```bash
     gpgconf --kill gpg-agent
     ```

#### 2. Unlock and Cache the Identity in your Active Agent

Alternatively, ensure your GPG or SSH credentials are fully unlocked and cached in your active session agent so that subsequent headless commits do not require re-verification prompts.

- **For GPG:** Configure a generous cache timeout in `gpg-agent.conf`:

  ```text
  default-cache-ttl 14400
  max-cache-ttl 86400
  ```

- **For SSH-based Commit Signing:** Ensure your private identity is pre-loaded and cached in `ssh-agent`:

  ```bash
  ssh-add -K
  ```
