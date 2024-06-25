# this module transforms a kubernetes cluster into a Rancher cluster

locals {
  rancher_domain          = var.project_domain
  rancher_version         = replace(var.rancher_version, "v", "") # don't include the v
  rancher_helm_repository = var.rancher_helm_repository
  cert_manager_version    = replace(var.cert_manager_version, "v", "") # don't include the v
}

# /var/lib/rancher/rke2/server/manifests/rke2-ingress-nginx-config.yaml
# ---
# apiVersion: helm.cattle.io/v1
# kind: HelmChartConfig
# metadata:
#   name: rke2-ingress-nginx
#   namespace: kube-system
# spec:
#   valuesContent: |-
#     controller:
#       config:
#         use-forwarded-headers: "true"
#       extraArgs:
#         default-ssl-certificate: "<namespace>/<secret_name>"

# resource "kubernetes_secret" "rancher-ingress-tls" {
#   metadata {
#     name = "rancher-ingress-tls"
#     namespace = "kube-system"
#   }
#   data = {
#     "tls.crt" = file("${path.module}/rancher-ingress-tls.crt")
#   }
# }

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  chart            = "https://charts.jetstack.io/charts/cert-manager-v${local.cert_manager_version}.tgz"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  timeout          = 1200 # 20m

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "time_sleep" "settle_before_rancher" {
  depends_on = [
    helm_release.cert_manager,
  ]
  create_duration = "30s"
}

resource "helm_release" "rancher_server" {
  depends_on = [
    helm_release.cert_manager,
    time_sleep.settle_before_rancher,
  ]
  name             = "rancher"
  chart            = "${local.rancher_helm_repository}/rancher-${local.rancher_version}.tgz"
  namespace        = "cattle-system"
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  timeout          = 1200 # 20m

  set {
    name  = "hostname"
    value = local.rancher_domain
  }

  set {
    name  = "replicas"
    value = "0"
  }

  set {
    name  = "bootstrapPassword"
    value = "admin"
  }
}
