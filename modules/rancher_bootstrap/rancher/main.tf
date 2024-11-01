provider "rancher2" {
  api_url   = "https://${local.rancher_domain}"
  bootstrap = true
}

locals {
  rancher_domain          = var.project_domain
  zone                    = var.zone
  region                  = var.region
  email                   = var.email
  rancher_version         = replace(var.rancher_version, "v", "") # don't include the v
  rancher_helm_repository = var.rancher_helm_repository
  cert_manager_version    = replace(var.cert_manager_version, "v", "") # don't include the v
  cert_manager_config     = var.cert_manager_configuration
  path                    = var.path
}

resource "time_sleep" "settle_before_rancher" {
  create_duration = "30s"
}

resource "kubernetes_namespace" "cattle-system" {
  depends_on = [
    time_sleep.settle_before_rancher,
  ]
  metadata {
    name = "cattle-system"
  }
  lifecycle {
    ignore_changes = [
      metadata,
    ]
  }
  provisioner "local-exec" {
    command = <<-EOT
    kubectl get namespace "cattle-system" -o json  \
     | tr -d "\n" \
     | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/"   \
     | kubectl replace --raw /api/v1/namespaces/cattle-system/finalize -f -
    EOT
    when    = destroy
  }
  provisioner "local-exec" {
    command = <<-EOT
      sleep 15
    EOT
    when    = destroy
  }
}

resource "kubernetes_secret" "aws_creds" {
  depends_on = [
    time_sleep.settle_before_rancher,
    kubernetes_namespace.cattle-system,
  ]
  metadata {
    name      = "prod-route53"
    namespace = "cattle-system"
  }
  data = {
    "secret-access-key" = local.cert_manager_config.aws_secret_access_key
    "access-key-id"     = local.cert_manager_config.aws_access_key_id
  }
  lifecycle {
    ignore_changes = [
      metadata,
    ]
  }
}

resource "kubernetes_manifest" "issuer" {
  depends_on = [
    time_sleep.settle_before_rancher,
    kubernetes_namespace.cattle-system,
    kubernetes_secret.aws_creds,
  ]
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Issuer"
    metadata = {
      name      = "rancher"
      namespace = "cattle-system"
      annotations = {
        "app.kubernetes.io/managed-by"   = "Helm"
        "meta.helm.sh/release-name"      = "rancher"
        "meta.helm.sh/release-namespace" = "cattle-system"
      }
      labels = {
        "app.kubernetes.io/managed-by" = "Helm"
      }
    }
    spec = {
      acme = {
        email  = local.email
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "acme-account-key"
        }
        solvers = [
          {
            selector = {
              dnsZones = [
                local.zone
              ]
            }
            dns01 = {
              route53 = {
                region = local.region
                accessKeyIDSecretRef = {
                  name = "prod-route53"
                  key  = "access-key-id"
                }
                secretAccessKeySecretRef = {
                  name = "prod-route53"
                  key  = "secret-access-key"
                }
              }
            }
          }
        ]
      }
    }
  }
  lifecycle {
    ignore_changes = [
      manifest.metadata,
    ]
  }
}

resource "terraform_data" "wait_for_nginx" {
  depends_on = [
    time_sleep.settle_before_rancher,
    kubernetes_secret.aws_creds,
    kubernetes_manifest.issuer,
  ]
  provisioner "local-exec" {
    command = <<-EOT
      EXITCODE=1
      ATTEMPTS=0
      MAX=3
      while [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt $MAX ]; do
        timeout 3600 kubectl rollout status daemonset -n kube-system rke2-ingress-nginx-controller --timeout=60s
        EXITCODE=$?
        ATTEMPTS=$((ATTEMPTS+1))
      done
      exit $EXITCODE
    EOT
  }
}

# https://github.com/rancher/rancher/blob/main/chart/values.yaml
resource "helm_release" "rancher" {
  depends_on = [
    time_sleep.settle_before_rancher,
    kubernetes_manifest.issuer,
    kubernetes_secret.aws_creds,
    terraform_data.wait_for_nginx,
  ]
  name             = "rancher"
  chart            = "${local.rancher_helm_repository}/rancher-${local.rancher_version}.tgz"
  namespace        = "cattle-system"
  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  force_update     = true
  timeout          = 2400 # 40m

  set {
    name  = "hostname"
    value = local.rancher_domain
  }
  set {
    name  = "replicas"
    value = "1"
  }
  set {
    name  = "bootstrapPassword"
    value = "admin"
  }
  set {
    name  = "ingress.enabled"
    value = "true"
  }
  set {
    name  = "ingress.tls.source"
    value = "letsEncrypt"
  }
  set {
    name  = "tls"
    value = "ingress"
  }
  set {
    name  = "letsEncrypt.ingress.class"
    value = "nginx"
  }
  set {
    name  = "letsEncrypt.environment"
    value = "production"
  }
  set {
    name  = "letsEncrypt.email"
    value = local.email
  }
  set {
    name  = "certmanager.version"
    value = local.cert_manager_version
  }
  set {
    name  = "ingress.extraAnnotations.cert-manager\\.io\\/issuer"
    value = "rancher"
  }
  set {
    name  = "agentTLSMode"
    value = "system-store"
  }
}

resource "time_sleep" "settle_after_rancher" {
  depends_on = [
    time_sleep.settle_before_rancher,
    kubernetes_manifest.issuer,
    helm_release.rancher,
    kubernetes_secret.aws_creds,
  ]
  create_duration = "120s"
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!$%&-_=+"
}

resource "terraform_data" "get_public_cert_info" {
  depends_on = [
    time_sleep.settle_before_rancher,
    kubernetes_manifest.issuer,
    helm_release.rancher,
    time_sleep.settle_after_rancher,
    kubernetes_secret.aws_creds,
  ]
  provisioner "local-exec" {
    command = <<-EOT
      CERT="$(echo | openssl s_client -showcerts -servername ${local.rancher_domain} -connect ${local.rancher_domain}:443 2>/dev/null | openssl x509 -inform pem -noout -text)"
      echo "$CERT"
      FAKE="$(echo "$CERT" | grep 'Kubernetes Ingress Controller Fake Certificate')"
      if [ -z "$FAKE" ]; then exit 0; else exit 1; fi
    EOT
  }
}
resource "rancher2_bootstrap" "admin" {
  depends_on = [
    time_sleep.settle_before_rancher,
    kubernetes_manifest.issuer,
    helm_release.rancher,
    time_sleep.settle_after_rancher,
    terraform_data.get_public_cert_info,
    kubernetes_secret.aws_creds,
  ]
  password  = random_password.password.result
  telemetry = false
}
