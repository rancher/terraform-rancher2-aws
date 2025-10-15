terraform {
  required_version = ">= 1.5.0"
  required_providers {
    file = {
      source  = "rancher/file"
      version = ">= 2.5"
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
      version = ">= 6.3"
    }
  }
}
