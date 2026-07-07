---
paths:
  - "**/*.tf"
---
# Terraform Rules

As an AI Agent operating in this repository, you MUST strictly adhere to the following Terraform coding standards. Do not deviate from these rules under any circumstances.

## 1. Syntax & Formatting Constraints

*   **Attribute Order**: You MUST declare resource attributes in this exact top-down order to ensure consistency:
    1. `count`
    2. `depends_on`
    3. `for_each`
    4. `source`
    5. `version`
    6. `triggers`
    7. *All other attributes*
*   **Explicit Dependencies**: You MUST always explicitly state `depends_on` blocks for resources and modules, even if Terraform can infer the dependency graph natively.
*   **Ternary Operations**: You MUST wrap all ternary operations in parentheses. 
    *   *Correct*: `attribute = (var.is_enabled ? true : false)`
    *   *Incorrect*: `attribute = var.is_enabled ? true : false`
*   **Embedded Scripts**: Avoid embedded scripts if possible (use `file()` or `templatefile()`). If embedding is required, you MUST use heredoc syntax (`<<-EOT`).

## 2. Variables & Locals (Strict Mapping)

*   **Locals Mapping**: ALL variables (`var.*`) MUST be immediately mapped to a `locals {}` block in the root of the module (usually `main.tf`).
*   **Resource Referencing**: Resources MUST ONLY reference `local.*`. You MUST NEVER reference `var.*` directly inside a `resource` or `module` block.

## 3. Count vs. Iteration

*   **Count as a Feature Flag**: You MUST ONLY use `count` as a boolean feature flag to turn a resource on or off (`0` or `1`).
    *   *Correct*: `count = (local.create_resource ? 1 : 0)`
*   **Never Iterate with Count**: You MUST NEVER use `count` to iterate over lists and create multiple instances of a resource. This causes cascading dependency destructions when list orders change. Use `for_each` instead.

## 4. Module Paradigms & Hierarchies

Understand the distinction between XMod (External), LMod (Local), and IMod (Implementation) modules.

*   **No Nesting Local Modules**: You MUST NEVER nest an LMod (Local Module) inside another LMod. Treat LMods like function calls orchestrated by the Implementation Module (IMod).
*   **Module Tiers (Max 3 Levels)**:
    *   **Core Modules**: Call only resources. NEVER call other modules.
    *   **Primary Modules**: Call only Core Modules (exceptions allowed for `local_file`, `random`, or `terraform_data`). NEVER call raw API resources.
    *   **Secondary Modules**: Call only Primary Modules. Represents large systems.
*   **Highly Opinionated Selectors**: Favor providing pre-defined configurations in `locals` (e.g., `prod-node-config`) rather than exposing raw, granular resource parameters via variables.

## 5. Provisioners & SSH Access

*   **Script Paths**: When using `remote-exec` or connection strings, you MUST ALWAYS explicitly set the `script_path` attribute to avoid SELinux execution blocks in `/tmp`.
*   **SSH Agent Only**: Modules MUST NOT generate or accept private SSH keys or passwords as variables unless strictly necessary for a specific cloud-init sequence. Assume the user relies on a local SSH agent.

## 6. Testing Terminology

When writing tests, adhere to these conceptual boundaries:
*   **Unit Test**: Tests a single Local Module (LMod) in isolation.
*   **Integration Test**: Tests the interaction between two or more LMods.
*   **E2E Test**: Tests the entire Implementation Module (IMod) with real provider interactions.
