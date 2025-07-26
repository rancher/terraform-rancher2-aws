terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.14"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = ">= 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.2"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.12.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.31.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.11"
    }
  }
}
