terraform {
  required_version = ">= 1.5.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.1.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.31.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.13.1"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.2"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.11"
    }
  }
}
