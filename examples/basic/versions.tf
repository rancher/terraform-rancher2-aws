terraform {
  required_version = ">= 1.5.0, < 1.6"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.1"
    }
    github = {
      source  = "integrations/github"
      version = ">= 5.44"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.11"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4"
    }
    null = {
      source  = "hashicorp/null"
      version = ">=3"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = ">= 2.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.3.3"
    }
  }
}
provider "acme" {
  server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
}
provider "github" {}
