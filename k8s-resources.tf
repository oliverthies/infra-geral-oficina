# ==================== NAMESPACE ====================

resource "kubernetes_namespace" "oficina" {
  metadata {
    name = var.project_name

    labels = {
      "app.kubernetes.io/part-of" = var.project_name
      "managed-by"                = "terraform"
    }
  }

  depends_on = [aws_eks_node_group.main]
}

# ==================== CONFIGMAP ====================

resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "oficina-config"
    namespace = kubernetes_namespace.oficina.metadata[0].name
  }

  data = {
    DB_HOST                = var.rds_address
    DB_PORT                = "5432"
    DB_NAME                = var.db_name
    MAIL_HOST              = "oficina-mailpit"
    MAIL_PORT              = "1025"
    SPRING_PROFILES_ACTIVE = "default"
    APP_VERSION            = "1.0.0"
  }

  depends_on = [kubernetes_namespace.oficina]
}

# ==================== SECRET ====================

resource "kubernetes_secret" "app_secret" {
  metadata {
    name      = "oficina-secret"
    namespace = kubernetes_namespace.oficina.metadata[0].name
  }

  data = {
    DB_USER           = var.db_user
    DB_PASSWORD       = var.db_password
    JWT_SECRET        = var.jwt_secret
    POSTGRES_USER     = var.db_user
    POSTGRES_PASSWORD = var.db_password
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.oficina]
}

# ==================== MAILPIT (pod no EKS) ====================

resource "kubernetes_deployment" "mailpit" {
  metadata {
    name      = "oficina-mailpit"
    namespace = kubernetes_namespace.oficina.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "oficina-mailpit"
      }
    }

    template {
      metadata {
        labels = {
          app = "oficina-mailpit"
        }
      }

      spec {
        container {
          name  = "mailpit"
          image = "axllent/mailpit:latest"

          port {
            container_port = 1025
            name           = "smtp"
          }
          port {
            container_port = 8025
            name           = "web"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.oficina]
}

resource "kubernetes_service" "mailpit" {
  metadata {
    name      = "oficina-mailpit"
    namespace = kubernetes_namespace.oficina.metadata[0].name
  }

  spec {
    selector = {
      app = "oficina-mailpit"
    }

    port {
      name        = "smtp"
      port        = 1025
      target_port = 1025
    }

    port {
      name        = "web"
      port        = 8025
      target_port = 8025
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_namespace.oficina]
}

# ==================== API DEPLOYMENT ====================

resource "kubernetes_deployment" "api" {
  metadata {
    name      = "oficina-api"
    namespace = kubernetes_namespace.oficina.metadata[0].name

    labels = {
      "app.kubernetes.io/name"    = "api"
      "app.kubernetes.io/part-of" = var.project_name
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "oficina-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "oficina-api"
        }
      }

      spec {
        container {
          name              = "oficina-api"
          image             = "${aws_ecr_repository.api.repository_url}:latest"
          image_pull_policy = "Always"

          port {
            container_port = 8080
          }

          env {
            name = "DB_HOST"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "DB_HOST"
              }
            }
          }
          env {
            name = "DB_PORT"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "DB_PORT"
              }
            }
          }
          env {
            name = "DB_NAME"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "DB_NAME"
              }
            }
          }
          env {
            name = "DB_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.app_secret.metadata[0].name
                key  = "DB_USER"
              }
            }
          }
          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.app_secret.metadata[0].name
                key  = "DB_PASSWORD"
              }
            }
          }
          env {
            name = "JWT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.app_secret.metadata[0].name
                key  = "JWT_SECRET"
              }
            }
          }
          env {
            name = "MAIL_HOST"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "MAIL_HOST"
              }
            }
          }
          env {
            name = "MAIL_PORT"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "MAIL_PORT"
              }
            }
          }
          env {
            name = "SPRING_PROFILES_ACTIVE"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "SPRING_PROFILES_ACTIVE"
              }
            }
          }

          readiness_probe {
            http_get {
              path = "/api/v1/actuator/health/readiness"
              port = 8080
            }
            initial_delay_seconds = 45
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          liveness_probe {
            http_get {
              path = "/api/v1/actuator/health/liveness"
              port = 8080
            }
            initial_delay_seconds = 90
            period_seconds        = 20
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          resources {
            requests = {
              cpu    = "200m"
              memory = "384Mi"
            }
            limits = {
              cpu    = "1"
              memory = "768Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.oficina,
    kubernetes_config_map.app_config,
    kubernetes_secret.app_secret,
  ]
}

# ==================== API SERVICE (LoadBalancer) ====================

resource "kubernetes_service" "api" {
  metadata {
    name      = "oficina-api"
    namespace = kubernetes_namespace.oficina.metadata[0].name

    labels = {
      "app.kubernetes.io/name"    = "api"
      "app.kubernetes.io/part-of" = var.project_name
    }
  }

  spec {
    selector = {
      app = "oficina-api"
    }

    port {
      port        = 80
      target_port = 8080
    }

    type = "LoadBalancer"
  }

  depends_on = [kubernetes_namespace.oficina]
}

# ==================== HPA ====================

resource "kubernetes_horizontal_pod_autoscaler_v2" "api" {
  metadata {
    name      = "oficina-api-hpa"
    namespace = kubernetes_namespace.oficina.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.api.metadata[0].name
    }

    min_replicas = 2
    max_replicas = 5

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.api]
}
