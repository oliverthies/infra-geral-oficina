# ==================== Namespaces — Microsserviços Fase 4 ====================
# Criados apenas se o cluster EKS existir (depends_on node group).
# Podem ser aplicados depois do bootstrap VPC/EKS.

resource "kubernetes_namespace" "ms_os" {
  metadata {
    name = "${var.project_name}-os"
    labels = {
      "app.kubernetes.io/part-of"   = var.project_name
      "app.kubernetes.io/component" = "os"
      "managed-by"                  = "terraform"
      "phase"                       = "4"
    }
  }

  depends_on = [aws_eks_node_group.main]
}

resource "kubernetes_namespace" "ms_billing" {
  metadata {
    name = "${var.project_name}-billing"
    labels = {
      "app.kubernetes.io/part-of"   = var.project_name
      "app.kubernetes.io/component" = "billing"
      "managed-by"                  = "terraform"
      "phase"                       = "4"
    }
  }

  depends_on = [aws_eks_node_group.main]
}

resource "kubernetes_namespace" "ms_execution" {
  metadata {
    name = "${var.project_name}-execution"
    labels = {
      "app.kubernetes.io/part-of"   = var.project_name
      "app.kubernetes.io/component" = "execution"
      "managed-by"                  = "terraform"
      "phase"                       = "4"
    }
  }

  depends_on = [aws_eks_node_group.main]
}
