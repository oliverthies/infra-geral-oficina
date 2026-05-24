# Infraestrutura Geral — Oficina Mecânica

Provisionamento da infraestrutura base na AWS via Terraform para o sistema de gestão de oficina mecânica.

**Deploy completo (todos os módulos Terraform, ordem EKS → RDS → API → Lambda):** [INFRA_DEPLOY.md](./INFRA_DEPLOY.md)

## Responsabilidade

Este repositório gerencia:

- **Amazon VPC** — rede isolada com subnets públicas e privadas
- **Amazon EKS** — cluster Kubernetes gerenciado com auto-scaling
- **Amazon ECR** — registry privado de imagens Docker
- **Security Groups** — regras de acesso de rede (cluster e nodes)
- **Kubernetes Resources** — namespace, ConfigMap, Secret, Mailpit, Deployment da API, Service (LoadBalancer), HPA

## Arquitetura

```
┌──────────────────────────────────────────────────────────────┐
│                        AWS Cloud                              │
│                                                               │
│  ┌─────────────────── VPC (10.0.0.0/16) ──────────────────┐  │
│  │                                                         │  │
│  │  ┌─── Public Subnets ───┐   ┌── Private Subnets ──┐    │  │
│  │  │  EKS Nodes (t3.medium)│  │  RDS PostgreSQL      │    │  │
│  │  │  LoadBalancer (ALB)  │   │  (infra-database)    │    │  │
│  │  └──────────────────────┘   └──────────────────────┘    │  │
│  │                                                         │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌── ECR ──┐                                                  │
│  │ oficina │                                                  │
│  │  -api   │                                                  │
│  └─────────┘                                                  │
└──────────────────────────────────────────────────────────────┘
```

## Pré-requisitos

- AWS CLI configurado com credenciais válidas
- Terraform >= 1.0
- kubectl
- O repositório [infra-database-oficina](https://github.com/oliverthies/infra-database-oficina) deve ser aplicado primeiro (fornece o endpoint RDS)

## Tecnologias

| Tecnologia | Uso |
|---|---|
| Terraform | Provisionamento de infraestrutura (IaC) |
| AWS EKS | Cluster Kubernetes gerenciado |
| AWS VPC | Rede isolada na nuvem |
| AWS ECR | Registry de imagens Docker |
| GitHub Actions | CI/CD (plan em PR, apply na main) |

## Estrutura

```
infra-geral-oficina/
├── .github/workflows/terraform.yml  # CI/CD
├── main.tf                          # Providers e locals
├── vpc.tf                           # VPC, subnets, IGW, route tables, SGs
├── eks.tf                           # Cluster EKS, node group, provider K8s
├── ecr.tf                           # ECR repository + lifecycle policy
├── k8s-resources.tf                 # Namespace, ConfigMap, Secret, Deployments, Services, HPA
├── variables.tf                     # Variáveis de entrada
├── outputs.tf                       # Outputs (IDs para outros repos)
├── terraform.tfvars.example         # Exemplo de variáveis
├── terraform.tfstate                # State versionado (sincronizado pelo CI)
├── scripts/
│   ├── setup.sh                     # Script de provisionamento completo
│   └── destroy.sh                   # Script de destruição
└── README.md
```

## Uso

### Execução local

```bash
# Copiar e preencher variáveis
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars com os valores reais

# Inicializar e aplicar
terraform init
terraform plan
terraform apply
```

### Via CI/CD (GitHub Actions)

O pipeline é disparado automaticamente:
- **Pull Request → main**: executa `terraform plan` (validação)
- **Push na main**: executa `terraform apply` e commita o state atualizado

### Scripts auxiliares

```bash
# Provisionamento guiado (interativo)
bash scripts/setup.sh

# Destruição de toda a infraestrutura
bash scripts/destroy.sh
```

## Outputs

Após o `terraform apply`, os seguintes valores ficam disponíveis para os outros repositórios:

| Output | Descrição | Consumidor |
|---|---|---|
| `vpc_id` | ID da VPC | infra-database-oficina |
| `private_subnet_ids` | IDs das subnets privadas | infra-database-oficina |
| `eks_cluster_security_group_id` | SG gerenciado pelo EKS | infra-database-oficina |
| `eks_nodes_security_group_id` | SG customizado dos nodes | infra-database-oficina |
| `ecr_repository_url` | URL do ECR | Repositório da API (`oficina-api` / [projeto-oficina](https://github.com/oliverthies/projeto-oficina)) — workflow `push-ecr.yml` |
| `api_load_balancer_hostname` | URL pública da API | Swagger/Postman |
| `kubeconfig_command` | Comando para configurar kubectl | Operação |

## CI/CD

As variáveis sensíveis são gerenciadas via **GitHub Secrets**:

| Secret | Descrição |
|---|---|
| `AWS_ACCESS_KEY_ID` | Credencial AWS |
| `AWS_SECRET_ACCESS_KEY` | Credencial AWS |
| `AWS_SESSION_TOKEN` | Token de sessão (Learner Lab) |
| `DB_USER` | Usuário do banco |
| `DB_PASSWORD` | Senha do banco |
| `JWT_SECRET` | Chave secreta JWT |
| `RDS_ADDRESS` | Endpoint do RDS (output do infra-database) |

> **Imagem da API:** publicada no ECR pelo repositório da API (Actions → *Build and Push API to ECR*), não por build Docker local. Ver [INFRA_DEPLOY.md](./INFRA_DEPLOY.md) passo 5.

**Governança:** PR obrigatório para `main` com `terraform plan` no PR e `apply` após merge; adicione **`soat-architecture`** como colaborador e habilite branch protection (1 approval + checks).

> **Nota:** As credenciais do AWS Learner Lab expiram a cada ~4 horas.
> Atualize os secrets `AWS_*` no GitHub (`oficina-api/scripts/update-github-aws-secrets.ps1`) antes do workflow ECR ou do pipeline Terraform.
> Em produção, recomenda-se backend remoto (S3 + DynamoDB) para o state.

## Repositórios relacionados

| Repositório | Descrição |
|---|---|
| [projeto-oficina](https://github.com/oliverthies/projeto-oficina) / `oficina-api` | Aplicação principal (API + manifests em `k8s/`) |
| [infra-database-oficina](https://github.com/oliverthies/infra-database-oficina) | Infraestrutura do banco de dados (RDS) |
| infra-geral-oficina | Este repositório |
