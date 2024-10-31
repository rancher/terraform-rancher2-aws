terraform {
  required_version = ">= 1.5.0, < 1.6"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.2"
    }
  }
}
