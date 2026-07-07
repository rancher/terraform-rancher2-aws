---
description: Architectural context and guidelines for the downstream cluster example.
globs: ["examples/downstream/**/*"]
---
# Downstream Example Rules

## Context Loading
When you are asked to troubleshoot, refactor, or add features to the downstream example, you MUST use your file-reading tools to read the following files into context before proceeding:
- `examples/downstream/main.tf` (to understand the current node configs and provider setups)
- `examples/downstream/modules/deploy/variables.tf` (to understand the inputs expected by the deployment module)
- `examples/downstream/modules/downstream_securitygroups/variables.tf` (to understand the inputs expected by the security group module)
- `examples/downstream/modules/downstream/variables.tf` (to understand the inputs expected by the downstream module)
- `examples/downstream/downstream/variables.tf` (to understand the inputs expected by the downstream module deployment)

When modifying files in the `examples/downstream` directory, strictly adhere to the following architectural guidelines, developer paradigms, and operational flows.

## Developer Paradigms
- **Local Modules (LMod)**: The subdirectories (`modules/`) are not independent; they act like function calls integral to the orchestration. **Never nest Local Modules inside one another.**
- **Highly Opinionated Selectors**: Use the `configs` local block in the root `main.tf` as a feature selector. Do not expose all Kubernetes parameters to the user; instead, rely on selecting a predefined architecture (like `prod-node-config` or `split-role-node-config`).
- **All Variables in Locals**: Map variables in `main.tf` immediately to a `locals` block. Resources must only reference these `locals` to isolate variable transformations.

## Execution Flow
When refactoring or adding features, ensure you respect and maintain the established execution flow:
1. **Upstream Deployment**: The root `main.tf` triggers the deployment of the parent module, provisioning an RKE2 cluster and installing Rancher.
2. **Rancher Authentication**: `rancher2_bootstrap` grabs the admin token and configures the default `rancher2` provider once the UI is available.
3. **Downstream Security**: `modules/downstream_securitygroups` maps network rules allowing the authenticated Rancher server to communicate with future downstream nodes.
4. **Downstream Networking**: `modules/downstream` establishes a private subnet and a NAT gateway for isolated node provisioning.
5. **Downstream Provisioning**: `modules/downstream` talks to the Rancher API to create Machine Configs (EC2 templates) and a new RKE2 Cluster definition. 
6. **State Syncing**: `rancher2_cluster_sync` blocks Terraform execution until the newly provisioned downstream cluster achieves an active state.

## Directory Structure Responsibilities

### `examples/downstream/` (Root Implementation Module)
- Keep logic focused on setting up the upstream cluster, provider authentication, and delegating to local modules. 
- Outputs should output sensitive connection and state data generated from the upstream cluster (kubeconfig, tokens, etc).

### `examples/downstream/modules/downstream_securitygroups/`
- Exclusively manage network boundaries and access rules (ingress/egress) for the downstream cluster.
- Ensure traffic is allowed between the downstream cluster, the load balancer, and the upstream Rancher cluster's security group.

### `examples/downstream/modules/downstream/`
- Manage downstream networking (subnets/Route Tables/NAT) to ensure downstream nodes are isolated from the public internet.
- Dynamically provision Machine Configs and map node roles (control plane, etcd, worker).
- Use `terraform_data` provisioners to execute credential patching via `addKeyToAmazonConfig.sh`.
- **Do not expose direct SSH outputs** since nodes reside in a private subnet.
