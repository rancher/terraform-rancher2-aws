terraform {
  required_version = ">= 1.5.0, < 1.6"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.15"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.32.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.12.0"
    }
  }
}
