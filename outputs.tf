output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas (para uso do infra-database)"
  value       = aws_subnet.private[*].id
}

output "eks_cluster_name" {
  description = "Nome do cluster EKS"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint do cluster EKS"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_version" {
  description = "Versão do Kubernetes no EKS"
  value       = aws_eks_cluster.main.version
}

output "eks_cluster_security_group_id" {
  description = "ID do SG gerenciado pelo EKS (para uso do infra-database)"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "eks_nodes_security_group_id" {
  description = "ID do SG customizado dos nodes EKS (para uso do infra-database)"
  value       = aws_security_group.eks_nodes.id
}

output "ecr_repository_url" {
  description = "URL do repositório ECR"
  value       = aws_ecr_repository.api.repository_url
}

output "api_load_balancer_hostname" {
  description = "Hostname do Load Balancer da API (URL pública)"
  value       = kubernetes_service.api.status[0].load_balancer[0].ingress[0].hostname
}

output "kubeconfig_command" {
  description = "Comando para configurar kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${local.cluster_name}"
}
