# Getting Started with Local Provider Development

Welcome to the `terraform-provider-file` project! This tutorial walks you through cloning the repository, establishing a hermetic development shell, building the Terraform provider binary, and running your very first local unit test.

---

## Prerequisites

Before starting, ensure you have the following installed on your machine:

- **Git** (for version control)
- **Nix** (for our hermetic development shell environment)
- **GnuPG (GPG)** (for commit and plan signing)

---

## Exercise 1: Set Up Your Hermetic Development Shell

In this repository, all tools (Go compilers, Terraform CLIs, linters, and formatters) are managed hermetically by Nix. This ensures that every developer runs the exact same compiler and dependency versions.

1. **Clone the repository:**

   ```bash
   git clone https://github.com/rancher/terraform-provider-file.git
   cd terraform-provider-file
   ```

2. **Enter the Nix development shell:**

   ```bash
   nix-shell
   ```

   _Note: On your first run, Nix will download all required toolchains and dependencies. This may take a few minutes. Once completed, your terminal prompt will change, indicating the shell is active._

## Exercise 2: Compile the Provider Binaries

Now that your Nix environment is active, you have access to the standard Go compiler. Let's compile the Terraform provider binary:

1. **Run the compilation script:**

   ```bash
   make build
   ```

2. **Verify the output:**
   Check the `bin/` directory to ensure the provider compiled successfully:

   ```bash
   ls -la bin/
   ```

## Exercise 3: Run Your First Local Unit Test

To guarantee everything works perfectly, execute the standard unit test suite:

1. **Execute the unit tests:**

   ```bash
   make test
   ```

2. **Check the results:**
   You should see standard Go test logs printed to your console, concluding with a clean `PASS` notification.

---

## Next Steps

Congratulations! You have successfully established your development environment, compiled the binary, and validated the build.

- Refer to our **[How-To Test Guide](../how-to/Testing.md)** to learn how to run advanced acceptance tests.
- Refer to our **[Reference Index](../reference/CodingStandards.md)** to verify coding conventions.
