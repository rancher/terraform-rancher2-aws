terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.11"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = ">= 14.0.0"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.4.0"
    }
  }
}
