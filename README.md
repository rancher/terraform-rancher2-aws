# Terraform Rancher Module

This module deploys infrastructure in AWS, installs rke2, then uses the rancher2 provider to install and configure rancher.
This module combines other modules that we provide to give holistic control of the lifecycle of the rancher cluster.
This is a secondary module, it deploys very little on its own, instead, it acts as an adapter/controller talking to other Terraform modules.
In some cases these modules need to exist on their own with heir own state for the infrastructure to scale properly.
To accomplish this we save the contents of the state files in our state file as a single resource and regenerate them if necessary on apply.
These child modules are saved base64 encoded in the root module's state file.

## Requirements

#### Provider Setup

Only two of the providers require setup:

- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) : [Config Reference](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#aws-configuration-reference)
- [GitHub Provider](https://registry.terraform.io/providers/integrations/github/latest/docs) : [Config Reference](https://registry.terraform.io/providers/integrations/github/latest/docs#argument-reference)

We recommend setting the following environment variables for quick personal use:

```shell
GITHUB_TOKEN
GITHUB_OWNER
AWS_REGION
AWS_SECRET_ACCESS_KEY
AWS_ACCESS_KEY_ID
ZONE
```

This module now supports the use of AWS temporary credentials to deploy cert manager.
At the moment it uses the same credentials supplied to generate the infrastructure,
 but in the future we intend to add the ability to supply cert manager specific credentials.
Make sure to set the AWS_SESSION_TOKEN environment variable when using this.

#### Tools

These tools will need to be installed on the machine running Terraform:
- curl
- jq
- kubectl
- terraform
- yq
- helm (v3)
- git

Check out the flake.nix file for a list of packages that we use when developing and testing (lines 50-80).

#### Local Filesystem Write Access

You will need write access to the filesystem on the server running Terraform.
If downloading the files from GitHub, then you will need about 2GB storage space available in the 'local_file_path' location (defaults to ./rke2).

## Examples

We have a few example implementations to get you started, these examples are tested in our CI before release.
When you use them, update the source and version to use the Terraform registry.

#### Local State

The specific use case for the example modules is temporary infrastructure for testing purposes.
With that in mind, it is not expected that we manage the resources as a team, therefore the state files are all stored locally.
If you would like to store the state files remotely, add a terraform backend file (`*.name.tfbackend`) to your root module.
https://www.terraform.io/language/settings/backends/configuration#file

Some of the submodules use internal local state files, but generally those are considered not necessary for the overall project.
If you are using remote state files and would like to be able to pass a backend file to the sub modules please open an issue.

## Development and Testing

#### Paradigms and Expectations

Please make sure to read [terraform.md](./terraform.md) to understand the paradigms and expectations that this module has for development.

#### Environment

It is important to us that all collaborators have the ability to develop in similar environments, so we use tools which enable this as much as possible.
These tools are not necessary, but they can make it much simpler to collaborate.

* I use [nix](https://nixos.org/) that I have installed using [their recommended script](https://nixos.org/download.html#nix-install-macos)
* I source the .envrc to get started
  * it sets up all needed dependencies and gives me a set of tools that I can use to test and write the Terraform module.
* I use the run_tests.sh script in this directory to run the tests
* I store my credentials in local files and generate a symlink to them
  * eg. `~/.config/github/default/rc`
  * this will be automatically sourced when you enter the nix environment (and unloaded when you leave)
  * see the `.envrc` and `.rcs` file for the implementation

#### Automated Tests

Our continuous integration tests using the GitHub [ubuntu-latest runner](https://github.com/actions/runner-images/blob/main/images/linux/Ubuntu2204-Readme.md), we then rely on Nix to deploy the additional dependencies.

It also has special integrations with AWS to allow secure authentication,
 see https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services for more information.

When running tests in an automated system there are two major concerns:
- make sure that your "identifier" is different between runs
  - AWS doesn't always delete resources immediately and if you are creating and deleting often it can have collisions
  - ACME limits the number of certificates with the same domain to two or three a week
- make sure your environment is clean between tests
  - install [the leftovers tool](https://github.com/genevieve/leftovers/releases/tag/v0.70.0)
  - install [the AWS CLI tool](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#getting-started-install-instructions)
  - run the "run_tests.sh" script with the "-c" option to clear out any AWS leftovers if the test fails
    - `./run_tests.sh -c "my-identifier"`
  - destroy the state file between failed tests
