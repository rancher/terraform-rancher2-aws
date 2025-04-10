provider "rancher2" {
  api_url   = "https://${local.rancher_domain}"
  bootstrap = true
}

locals {
  rancher_domain       = var.project_domain
  zone_id              = var.zone_id
  region               = var.region
  email                = var.email
  rancher_version      = replace(var.rancher_version, "v", "") # don't include the v
  rancher_minor        = split(".", local.rancher_version)[1]
  telemetry            = (local.rancher_minor < 11 ? 1 : 0)
  cert_manager_version = replace(var.cert_manager_version, "v", "") # don't include the v
  acme_server          = var.acme_server_url
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

resource "kubernetes_manifest" "issuer" {
  depends_on = [
    time_sleep.settle_before_rancher,
    kubernetes_namespace.cattle-system,
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
        server = "${local.acme_server}/directory" # "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "acme-account-key"
        }
        solvers = [
          # https://cert-manager.io/docs/reference/api-docs/#acme.cert-manager.io/v1.ACMEChallengeSolver
          {
            # https://cert-manager.io/docs/reference/api-docs/#acme.cert-manager.io/v1.ACMEIssuerDNS01ProviderRoute53
            # https://cert-manager.io/docs/configuration/acme/dns01/route53/#ambient-credentials
            # https://docs.aws.amazon.com/sdkref/latest/guide/environment-variables.html
            dns01 = {
              route53 = {
                ambient      = true
                region       = local.region
                hostedZoneID = local.zone_id
              }
            }
          }
        ]
      }
    }
  }
}

resource "terraform_data" "wait_for_nginx" {
  depends_on = [
    time_sleep.settle_before_rancher,
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
        if [ $EXITCODE -gt 0 ]; then
          timeout 3600 kubectl get pods -A
        fi
        ATTEMPTS=$((ATTEMPTS+1))
      done
      exit $EXITCODE
    EOT
  }
}

# WARNING! This adds git, yq, and helm to the dependency list!
resource "terraform_data" "build_chart" {
  depends_on = [
    time_sleep.settle_before_rancher,
  ]
  provisioner "local-exec" {
    command = <<-EOT
      cd ${abspath(path.root)} || true
      if [ -d chart ]; then
        rm -rf chart
      fi
      mkdir chart
      cd chart || exit 1
      ${abspath(path.module)}/build_chart.sh "${local.rancher_version}"
      cd ${abspath(path.root)} || true
      mv chart/rancher-${local.rancher_version}.tgz .
      rm -rf chart
      ls ${abspath(path.root)}/rancher-${local.rancher_version}.tgz
    EOT
  }
}

# https://github.com/rancher/rancher/blob/main/chart/values.yaml
resource "helm_release" "rancher" {
  depends_on = [
    time_sleep.settle_before_rancher,
    kubernetes_manifest.issuer,
    terraform_data.wait_for_nginx,
    terraform_data.build_chart,
  ]
  name             = "rancher"
  chart            = "${path.root}/rancher-${local.rancher_version}.tgz" # "${local.rancher_helm_repository}/${local.rancher_channel}/rancher-${local.rancher_version}.tgz"
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
  ]
  create_duration = "120s"
}


resource "terraform_data" "get_public_cert_info" {
  depends_on = [
    time_sleep.settle_before_rancher,
    kubernetes_manifest.issuer,
    helm_release.rancher,
    time_sleep.settle_after_rancher,
  ]
  provisioner "local-exec" {
    command = <<-EOT
      MAX=4
      ATTEMPTS=0
      E=""
      INTERVAL=30 # seconds
      while [ $ATTEMPTS -lt $MAX ]; do
        CERT="$(echo | openssl s_client -showcerts -servername ${local.rancher_domain} -connect ${local.rancher_domain}:443 2>/dev/null | openssl x509 -inform pem -noout -text)"
        echo "$CERT"
        FAKE="$(echo "$CERT" | grep 'Kubernetes Ingress Controller Fake Certificate')"
        if [ -z "$FAKE" ]; then
          echo "verified certificate is not fake"
          ATTEMPTS=$MAX
          E=""
        else
          ATTEMPTS=$((ATTEMPTS+1))
          SLEEPTIME=$((INTERVAL*ATTEMPTS))
          echo "certificate is fake! retrying in $SLEEPTIME seconds..."
          sleep $SLEEPTIME
          E="certificate is fake"
        fi;
      done
      if [ -z "$E" ]; then
        exit 0
      else
        echo "$E"
        timeout 3600 kubectl get order -A
        timeout 3600 kubectl get challenge -A
        timeout 3600 kubectl describe order -n cattle-system
        timeout 3600 kubectl describe challenge -n cattle-system
        exit 1
      fi
    EOT
  }
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!-_=+"
}

resource "rancher2_bootstrap" "admin" {
  depends_on = [
    time_sleep.settle_before_rancher,
    kubernetes_manifest.issuer,
    helm_release.rancher,
    time_sleep.settle_after_rancher,
    terraform_data.get_public_cert_info,
  ]
  password = random_password.password.result
}
