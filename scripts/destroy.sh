#!/bin/bash
# ============================================================
# Script para destruir toda a infraestrutura AWS
# USE COM CUIDADO - todos os dados serão perdidos!
# ============================================================

set -e

echo "============================================"
echo "  Oficina API - Destruir Infraestrutura AWS"
echo "============================================"
echo ""
echo "ATENÇÃO: Isso vai destruir TODOS os recursos:"
echo "  - Cluster EKS (Kubernetes)"
echo "  - Banco RDS PostgreSQL (TODOS OS DADOS)"
echo "  - Repositório ECR (TODAS AS IMAGENS)"
echo "  - VPC e redes associadas"
echo ""
read -p "Tem certeza? Digite 'DESTRUIR' para confirmar: " CONFIRM

if [ "$CONFIRM" != "DESTRUIR" ]; then
    echo "Operação cancelada."
    exit 0
fi

echo ""
echo "Destruindo infraestrutura..."
terraform destroy -auto-approve

echo ""
echo "============================================"
echo "  Infraestrutura destruída com sucesso!"
echo "============================================"
