#!/bin/bash
# ============================================================
# Script de setup para infraestrutura AWS
# Provisiona: VPC, EKS, RDS, ECR, K8s resources
# ============================================================

set -e

echo "============================================"
echo "  Oficina API - Setup AWS Infrastructure"
echo "============================================"

# Verificar pré-requisitos
echo ""
echo "[1/7] Verificando pré-requisitos..."

if ! command -v aws &> /dev/null; then
    echo "ERRO: AWS CLI não encontrado. Instale com: brew install awscli"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo "ERRO: Terraform não encontrado. Instale com: brew install terraform"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "ERRO: kubectl não encontrado. Instale com: brew install kubectl"
    exit 1
fi

# Verificar credenciais AWS
echo ""
echo "[2/7] Verificando credenciais AWS..."
aws sts get-caller-identity > /dev/null 2>&1 || {
    echo "ERRO: Credenciais AWS não configuradas."
    echo "Configure com: aws configure"
    echo "E exporte AWS_SESSION_TOKEN se usando AWS Academy"
    exit 1
}
echo "OK - Autenticado na AWS"

# Terraform init
echo ""
echo "[3/7] Inicializando Terraform..."
terraform init

# Terraform plan
echo ""
echo "[4/7] Gerando plano de execução..."
terraform plan -out=tfplan

echo ""
echo "============================================"
echo "  ATENÇÃO: Revise o plano acima!"
echo "  Recursos serão criados na AWS (custo ~\$0.30/hora)"
echo "============================================"
echo ""
read -p "Deseja continuar? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operação cancelada."
    rm -f tfplan
    exit 0
fi

# Terraform apply
echo ""
echo "[5/7] Criando infraestrutura AWS (isso pode levar ~15-20 minutos)..."
terraform apply tfplan
rm -f tfplan

# Configurar kubectl
echo ""
echo "[6/7] Configurando kubectl para o cluster EKS..."
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
AWS_REGION=$(terraform output -raw 2>/dev/null || echo "us-east-1")
aws eks update-kubeconfig --region us-east-1 --name $CLUSTER_NAME

# Push da imagem Docker para ECR
echo ""
echo "[7/7] Informações para push da imagem Docker..."
ECR_URL=$(terraform output -raw ecr_repository_url)

echo ""
echo "============================================"
echo "  INFRAESTRUTURA CRIADA COM SUCESSO!"
echo "============================================"
echo ""
echo "Para enviar a imagem Docker para o ECR:"
echo ""
echo "  # Login no ECR"
echo "  aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URL"
echo ""
echo "  # Build e push"
echo "  cd ../../oficina-api"
echo "  docker build -t oficina-api ."
echo "  docker tag oficina-api:latest $ECR_URL:latest"
echo "  docker push $ECR_URL:latest"
echo ""
echo "Endpoints:"
echo "  EKS: $(terraform output -raw eks_cluster_endpoint)"
echo "  RDS: $(terraform output -raw rds_endpoint)"
echo "  ECR: $ECR_URL"
echo "  API: $(terraform output -raw api_load_balancer_hostname 2>/dev/null || echo 'Aguardando LoadBalancer...')"
echo ""
echo "Para inicializar o banco de dados:"
echo "  kubectl port-forward -n oficina svc/oficina-api 8080:80"
echo "  # Acesse http://localhost:8080/api/v1/swagger-ui/index.html"
echo ""
echo "LEMBRE-SE: Destrua os recursos quando terminar!"
echo "  terraform destroy"
echo ""
