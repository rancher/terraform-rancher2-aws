terraform {
  required_version = ">= 1.5.0, < 1.6"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.14"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = ">= 4.1.0, < 5.0"
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

# provider "kubernetes" {
#   config_path = "${path.root}/kubeconfig"
# }

# provider "helm" {
#   kubernetes {
#     config_path = "${path.root}/kubeconfig"
#   }
# }

# provider "rancher2" {
#   alias = "bootstrap"
#   api_url  = "https://${var.rancher_server_dns}"
#   insecure = false
#   bootstrap = true
# }

# provider "rancher2" {
#   alias = "admin"
#   api_url  = "https://${var.rancher_server_dns}"
#   insecure = true
#   # ca_certs  = data.kubernetes_secret.rancher_cert.data["ca.crt"]
#   token_key = rancher2_bootstrap.admin.token
#   timeout   = "300s"
# }
