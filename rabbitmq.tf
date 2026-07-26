# ==================== RabbitMQ — Mensageria Fase 4 (Saga) ====================
# Deployment simples no namespace oficina-os (acessível pelos 3 MS via DNS de cluster).
# Service DNS: rabbitmq.oficina-os.svc.cluster.local:5672
# Management UI: porta 15672 (ClusterIP — use port-forward)

resource "kubernetes_secret" "rabbitmq" {
  metadata {
    name      = "rabbitmq-secret"
    namespace = kubernetes_namespace.ms_os.metadata[0].name
  }

  data = {
    RABBITMQ_DEFAULT_USER = var.rabbitmq_user
    RABBITMQ_DEFAULT_PASS = var.rabbitmq_password
    RABBITMQ_HOST         = "rabbitmq.${var.project_name}-os.svc.cluster.local"
    RABBITMQ_PORT         = "5672"
  }

  depends_on = [kubernetes_namespace.ms_os]
}

resource "kubernetes_deployment" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace.ms_os.metadata[0].name
    labels = {
      app     = "rabbitmq"
      part-of = var.project_name
      phase   = "4"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "rabbitmq"
      }
    }

    template {
      metadata {
        labels = {
          app = "rabbitmq"
        }
      }

      spec {
        container {
          name  = "rabbitmq"
          image = "rabbitmq:3.13-management-alpine"

          port {
            name           = "amqp"
            container_port = 5672
          }

          port {
            name           = "management"
            container_port = 15672
          }

          env {
            name = "RABBITMQ_DEFAULT_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.rabbitmq.metadata[0].name
                key  = "RABBITMQ_DEFAULT_USER"
              }
            }
          }

          env {
            name = "RABBITMQ_DEFAULT_PASS"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.rabbitmq.metadata[0].name
                key  = "RABBITMQ_DEFAULT_PASS"
              }
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          liveness_probe {
            tcp_socket {
              port = 5672
            }
            initial_delay_seconds = 30
            period_seconds        = 20
          }

          readiness_probe {
            tcp_socket {
              port = 5672
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }
        }
      }
    }
  }

  depends_on = [kubernetes_secret.rabbitmq, aws_eks_node_group.main]
}

resource "kubernetes_service" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace.ms_os.metadata[0].name
    labels = {
      app = "rabbitmq"
    }
  }

  spec {
    selector = {
      app = "rabbitmq"
    }

    port {
      name        = "amqp"
      port        = 5672
      target_port = 5672
    }

    port {
      name        = "management"
      port        = 15672
      target_port = 15672
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.rabbitmq]
}

# Secrets espelhados nos namespaces billing e execution (mesmas credenciais)
resource "kubernetes_secret" "rabbitmq_billing" {
  metadata {
    name      = "rabbitmq-secret"
    namespace = kubernetes_namespace.ms_billing.metadata[0].name
  }

  data = {
    RABBITMQ_DEFAULT_USER = var.rabbitmq_user
    RABBITMQ_DEFAULT_PASS = var.rabbitmq_password
    RABBITMQ_HOST         = "rabbitmq.${kubernetes_namespace.ms_os.metadata[0].name}.svc.cluster.local"
    RABBITMQ_PORT         = "5672"
  }

  depends_on = [kubernetes_namespace.ms_billing]
}

resource "kubernetes_secret" "rabbitmq_execution" {
  metadata {
    name      = "rabbitmq-secret"
    namespace = kubernetes_namespace.ms_execution.metadata[0].name
  }

  data = {
    RABBITMQ_DEFAULT_USER = var.rabbitmq_user
    RABBITMQ_DEFAULT_PASS = var.rabbitmq_password
    RABBITMQ_HOST         = "rabbitmq.${kubernetes_namespace.ms_os.metadata[0].name}.svc.cluster.local"
    RABBITMQ_PORT         = "5672"
  }

  depends_on = [kubernetes_namespace.ms_execution]
}
