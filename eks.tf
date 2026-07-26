# ==================== IAM ROLES (pré-existentes no AWS Academy) ====================
# O AWS Academy não permite criar IAM Roles — usamos as roles do Lab.

data "aws_iam_role" "eks_cluster" {
  name = "c220532a5561746l15967798t1w468392-LabEksClusterRole-Cjao7xeLnIaV"
}

data "aws_iam_role" "eks_nodes" {
  name = "c220532a5561746l15967798t1w468392890-LabEksNodeRole-FxQeXx16husn"
}

# ==================== EKS CLUSTER ====================

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = data.aws_iam_role.eks_cluster.arn
  version  = "1.30"

  vpc_config {
    subnet_ids              = aws_subnet.public[*].id
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  tags = local.common_tags
}

# ==================== EKS NODE GROUP ====================

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"
  node_role_arn   = data.aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.public[*].id

  instance_types = [var.eks_node_instance_type]

  scaling_config {
    desired_size = var.eks_node_desired
    min_size     = var.eks_node_min
    max_size     = var.eks_node_max
  }

  update_config {
    max_unavailable = 1
  }

  tags = local.common_tags
}

# ==================== KUBERNETES PROVIDER (após EKS criado) ====================

data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}

provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}
