terraform {
  required_version = ">= 1.5.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.14"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.31.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.2"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.12.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.11"
    }
  }
}
