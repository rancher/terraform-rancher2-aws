# Terraform Rancher Module

This module deploys infrastructure in AWS, installs rke2, then uses the rancher2 provider to install and configure rancher.
This module combines other modules that we provide to give holistic control of the lifecycle of the rancher cluster.

## Requirements

#### Provider Setup

Only two of the providers require setup:

- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) : [Config Reference](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#aws-configuration-reference)
- [GitHub Provider](https://registry.terraform.io/providers/integrations/github/latest/docs) : [Config Reference](https://registry.terraform.io/providers/integrations/github/latest/docs#argument-reference)

We recommend setting the following environment variables for quick personal use:

```shell
GITHUB_TOKEN
AWS_REGION
AWS_SECRET_ACCESS_KEY
AWS_ACCESS_KEY_ID
ZONE
```

#### Tools

These tools will need to be installed on the machine running Terraform:
- curl
- jq
- kubectl
- terraform

#### Local Filesystem Write Access

You will need write access to the filesystem on the server running Terraform.
If downloading the files from GitHub, then you will need about 2GB storage space available in the 'local_file_path' location (defaults to ./rke2).

#### Terraform Version

We specify the Terraform version < 1.6 to avoid potential license issues and version > 1.5.7 to enable custom variable validations.

## Examples

We have a few example implementations to get you started, these examples are tested in our CI before release.
When you use them, update the source and version to use the Terraform registry.

#### Local State

The specific use case for the example modules is temporary infrastructure for testing purposes.
With that in mind, it is not expected that we manage the resources as a team, therefore the state files are all stored locally.
If you would like to store the state files remotely, add a terraform backend file (`*.name.tfbackend`) to your root module.
https://www.terraform.io/language/settings/backends/configuration#file

## Development and Testing

#### Paradigms and Expectations

Please make sure to read [terraform.md](./terraform.md) to understand the paradigms and expectations that this module has for development.

#### Environment

It is important to us that all collaborators have the ability to develop in similar environments, so we use tools which enable this as much as possible.
These tools are not necessary, but they can make it much simpler to collaborate.

* I use [nix](https://nixos.org/) that I have installed using [their recommended script](https://nixos.org/download.html#nix-install-macos)
* I source the .envrc to get started
  * it sets up all needed dependencies and gives me a set of tools that I can use to test and write the Terraform module.
* I use the run_tests.sh script in this directory to run the tests, along with the alias 'tt'
  * eg. `tt -r` will rerun failed tests (once only)
  * eg. `tt -f=BasicTest` will run only the BasicTest
* I store my credentials in a local files and generate a symlink to them
  * eg. `~/.config/github/default/rc`
  * this will be automatically sourced when you enter the nix environment (and unloaded when you leave)
  * see the `.envrc` and `.rcs` file for the implementation

#### Automated Tests

Our continuous integration tests using the GitHub [ubuntu-latest runner](https://github.com/actions/runner-images/blob/main/images/linux/Ubuntu2204-Readme.md), we then rely on Nix to deploy the additional dependencies.

It also has special integrations with AWS to allow secure authentication, see https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services for more information.

With this tool it is possible to retrieve the aws access key and aws secret key to the temporarily defined access to the AWS account.
We send these to Rancher when building our tests, this allows us to temporarily and securely setup certmanger and Rancher provisioning.
