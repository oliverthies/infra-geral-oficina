# Infraestrutura Fase 4 — Microsserviços

Decisões travadas:

| Item | Escolha |
|------|---------|
| MS | `ms-os-oficina`, `ms-billing-oficina`, `ms-execution-oficina` |
| Mensageria | RabbitMQ no EKS (`rabbitmq.oficina-os.svc.cluster.local:5672`) |
| NoSQL Billing | DynamoDB `oficina-billing` |
| SQL | 1 RDS, databases `oficina_os` + `oficina_execution` (users `os_app` / `execution_app`) |

## Arquivos novos

### `infra-geral-oficina`

| Arquivo | Recurso |
|---------|---------|
| `ecr-microservices.tf` | ECR `oficina-os`, `oficina-billing`, `oficina-execution` |
| `dynamodb-billing.tf` | Tabela DynamoDB + GSI `gsi1` (serviceOrderId) |
| `k8s-fase4-namespaces.tf` | Namespaces `oficina-os`, `oficina-billing`, `oficina-execution` |
| `rabbitmq.tf` | Deployment + Service RabbitMQ + Secrets |

### `infra-database`

| Arquivo | Recurso |
|---------|---------|
| `fase4-databases.tf` | Variáveis + `null_resource` opcional |
| `scripts/provision-ms-databases.sh` | Job K8s que cria DBs/roles no RDS |

## Ordem de apply (lab ativo)

### 1) Sem cluster (só AWS “puro”)

No `infra-geral-oficina`, com credenciais válidas:

```powershell
cd infra-geral-oficina
terraform init -reconfigure
terraform apply `
  -target=aws_ecr_repository.microservice `
  -target=aws_ecr_lifecycle_policy.microservice `
  -target=aws_dynamodb_table.billing
```

### 2) Com EKS no ar

1. Suba/reaplique `infra-geral-oficina` completo (VPC + EKS + recursos Fase 4 K8s).
2. Garanta `rabbitmq_password` no `terraform.tfvars`.
3. Suba/reaplique `infra-database` (RDS).
4. Provisionar databases lógicos:

```powershell
cd infra-database
# Opção A — variável Terraform
# provision_ms_databases = true no tfvars, depois terraform apply

# Opção B — script manual (recomendado na primeira vez)
$env:OS_DB_PASSWORD="oficina-os-2026"
$env:EXECUTION_DB_PASSWORD="oficina-execution-2026"
bash ./scripts/provision-ms-databases.sh `
  "<rds-address>" 5432 oficina "oficina2026!" oficina-os
```

(Git Bash / WSL para o `bash`.)

### 3) Conferir

```powershell
aws ecr describe-repositories --query "repositories[?contains(repositoryName,'oficina')].repositoryName"
aws dynamodb describe-table --table-name oficina-billing --query "Table.TableStatus"
kubectl get ns -l phase=4
kubectl get pods -n oficina-os -l app=rabbitmq
```

## Outputs úteis

```powershell
cd infra-geral-oficina
terraform output ecr_microservice_urls
terraform output dynamodb_billing_table_name
terraform output rabbitmq_amqp_host
terraform output fase4_namespaces
```

## Próximo passo (código)

Scaffold Clean Architecture dos 3 repos + CI apontando para os ECRs acima.
