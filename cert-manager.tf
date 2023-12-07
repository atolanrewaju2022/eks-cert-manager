resource "kubernetes_namespace" "cert_manager" {
  metadata {
    labels = {
      "name" = "cert-manager"
    }
    name = "cert-manager"
  }
}

resource "helm_release" "cert_manager" {

  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.13.1"
  namespace  = kubernetes_namespace.cert_manager.metadata.0.name

  set {
    name  = "installCRDs"
    value = "false"
  }

  set {
    name = "serviceAccount.name"
    value = "cert-manager"
  }

  set {
    name = "serviceAccount.create"
    value = "false"
  }

  set {
    name = "rbac.create"
    value = "true"
  }

  depends_on = [
    kubernetes_namespace.cert_manager,
    kubernetes_service_account.service_account
  ]

}

resource "kubernetes_manifest" "clusterissuer_letsencrypt" {
  depends_on = [
    kubernetes_namespace.cert_manager,
    helm_release.cert_manager

  ]
  manifest = {
    "apiVersion" = "cert-manager.io/v1beta1"
    "kind" = "ClusterIssuer"
    "metadata" = {
      "name" = "letsencrypt"
    
    }
    "spec" = {
      "acme" = {
        "email" = "eng-serv@nav.com"
        "privateKeySecretRef" = {
          "name" = "nav-issuer-account-key"
        }
        "server" = "https://acme-v02.api.letsencrypt.org/directory"
        "solvers" = [
          {
            "dns01" = {
              "route53" = {
                "hostedZoneID" = "Z034937225IMPVACM1IEN" #int4 public hosted zone id 
                "region" = "us-east-1"
                "role" = "arn:aws:iam::325685483689:role/cert-manager-letsencrypt" 
              }
            }
          },
        ]
      }
    }
  }
}

resource "kubernetes_manifest" "cert_manager_letsencrypt" {
  depends_on = [
    kubernetes_namespace.cert_manager,
    helm_release.cert_manager,
    kubernetes_manifest.clusterissuer_letsencrypt
  ]
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind" = "Certificate"
    "metadata" = {
      "name" = "letsencrypt-cert"
      "namespace" = "default"
    }
    "spec" = {
      "dnsNames" = [
        "pod-tls.int4.nav.com",
      ]
      "issuerRef" = {
        "kind" = "ClusterIssuer"
        "name" = "letsencrypt"
      }
      "secretName" = "letsencrypt-cert"
    }
  }

}

resource "kubernetes_service_account" "service_account" {     
  metadata {
    name = "cert-manager"
    namespace = "cert-manager"
    labels = {
        "app.kubernetes.io/name" = "cert-manager"
        "app.kubernetes.io/component"= "cert-manager"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::325685483689:role/cert-manager-service-account-role"
    }
  }
  
}

# ###########################################################
# Cert manager k8s secret 
# ###########################################################
# resource "kubernetes_manifest" "lets_encrypt_secret" {
#   manifest = {
#     "apiVersion" = "v1"
#     "kind" = "Secret"
#     "metadata" = {
#       "name" = "tls-cert-secret"
#       "namespace" = "default"
#     }
#   }
# }
