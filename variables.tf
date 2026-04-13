variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto (usado como prefixo)"
  type        = string
  default     = "oficina"
}

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
  default     = "oficina"
}

variable "db_user" {
  description = "Usuário do banco de dados"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Senha do banco de dados (mínimo 8 caracteres)"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "Chave secreta JWT"
  type        = string
  sensitive   = true
}

variable "eks_node_instance_type" {
  description = "Tipo de instância EC2 para os nodes do EKS"
  type        = string
  default     = "t3.small"
}

variable "eks_node_desired" {
  description = "Número desejado de nodes"
  type        = number
  default     = 1
}

variable "eks_node_min" {
  description = "Número mínimo de nodes"
  type        = number
  default     = 1
}

variable "eks_node_max" {
  description = "Número máximo de nodes"
  type        = number
  default     = 2
}

variable "rds_address" {
  description = "Hostname do RDS PostgreSQL (output do repositório infra-database)"
  type        = string
}
