terraform {
  required_version = ">= 1.5.7, < 1.6"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.11"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4"
    }
    acme = {
      source  = "vancluever/acme"
      version = ">= 2.0"
    }
    github = {
      source  = "integrations/github"
      version = "6.2.2"
    }
  }
}

# provider "acme" {
#   server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
# }
# provider "github" {}
