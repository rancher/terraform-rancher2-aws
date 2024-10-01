terraform {
  required_version = ">= 1.5.0, < 1.6"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.14"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = ">= 4.1.0, < 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.31.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.2"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3.4"
    }
  }
}
