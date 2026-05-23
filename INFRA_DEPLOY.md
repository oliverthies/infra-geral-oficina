# Deploy da Infraestrutura na AWS

Guia **canônico** de provisionamento do Tech Challenge Fase 3. Este arquivo vive no repositório **[infra-geral-oficina](https://github.com/oliverthies/infra-geral-oficina)** (VPC, EKS, ECR, Kubernetes da API).

Cópia espelhada para leitura junto à documentação da API: [projeto-oficina/docs/INFRA_DEPLOY.md](https://github.com/oliverthies/projeto-oficina/blob/main/docs/INFRA_DEPLOY.md).

## Repositórios GitHub

| # | Repositório | Responsabilidade |
|---|-------------|------------------|
| 1 | [projeto-oficina](https://github.com/oliverthies/projeto-oficina) | API Spring Boot, K8s manifests, RFC/ADR, CI → ECR |
| 2 | [infra-geral-oficina](https://github.com/oliverthies/infra-geral-oficina) | VPC, EKS, ECR, deploy da API no cluster (**este repo**) |
| 3 | [infra-database-oficina](https://github.com/oliverthies/infra-database-oficina) | RDS PostgreSQL |
| 4 | [lambda-auth-oficina](https://github.com/oliverthies/lambda-auth-oficina) | Lambda CPF → JWT, API Gateway |

> **Desenvolvimento local:** os quatro repositórios costumam ficar lado a lado em uma pasta workspace (ex.: `oficina-project/`). Ajuste `$ROOT` nos comandos abaixo.

```powershell
# Pasta pai dos repositórios clonados (ajuste para seu ambiente)
$ROOT = "C:\Users\olive\OneDrive\Área de Trabalho\oficina-project"
```

---

Este documento descreve o passo a passo para criar a infraestrutura do projeto do zero na AWS.

> Regra principal: o banco PostgreSQL/RDS precisa estar criado e acessível antes da API subir no EKS.

## Visão geral

O projeto está dividido em módulos Terraform independentes:

- `terraform-backend`: cria o backend remoto do Terraform em S3 + DynamoDB.
- `infra-geral-oficina`: cria VPC, subnets, EKS, ECR e recursos Kubernetes da API.
- `infra-database`: cria o RDS PostgreSQL.
- `lambda-auth-oficina/terraform`: cria a Lambda de autenticação e o API Gateway.

Existe uma dependência cruzada entre `infra-geral-oficina` e `infra-database`:

- `infra-database` precisa dos outputs de rede do `infra-geral-oficina`.
- `infra-geral-oficina` precisa do `rds_address` gerado por `infra-database` para subir a API.

Por isso, o primeiro apply de `infra-geral-oficina` deve ser parcial, criando apenas VPC, EKS e ECR. Depois o banco é criado. Só então o apply completo da API deve ser executado.

## Documentação de arquitetura

Repositório da API: **[projeto-oficina](https://github.com/oliverthies/projeto-oficina)**

- **RFC 0001** (stack AWS, EKS, Lambda, RDS, Terraform): [docs/rfc/0001-plataforma-aws-fase3.md](https://github.com/oliverthies/projeto-oficina/blob/main/docs/rfc/0001-plataforma-aws-fase3.md)
- **ADR 0001** (observabilidade / New Relic): [docs/adr/0001-observabilidade-metricas-negocio-e-alertas.md](https://github.com/oliverthies/projeto-oficina/blob/main/docs/adr/0001-observabilidade-metricas-negocio-e-alertas.md)
- **Diagramas** (C4 nuvem, sequência, ER): [docs/diagrams/README.md](https://github.com/oliverthies/projeto-oficina/blob/main/docs/diagrams/README.md)

## Observabilidade (New Relic)

Instruções completas: [projeto-oficina/docs/NEW_RELIC.md](https://github.com/oliverthies/projeto-oficina/blob/main/docs/NEW_RELIC.md).

Resumo:

1. Defina `$env:NEW_RELIC_LICENSE_KEY` e execute `oficina-api/scripts/install-newrelic.ps1`
2. Faça build/push da imagem da API (agente Java no Dockerfile)
3. `kubectl apply -f oficina-api/k8s/api/deployment.yaml`

## Pré-requisitos

- AWS CLI configurado.
- Terraform instalado.
- Docker instalado, se for fazer build/push local da imagem da API.
- Credenciais AWS válidas no terminal.
- Se estiver usando AWS Academy/Learner Lab, exportar também `AWS_SESSION_TOKEN`.

Valide a autenticação:

```powershell
aws sts get-caller-identity
```

## 1. Criar o backend remoto do Terraform

Este passo cria:

- bucket S3 para armazenar os `terraform.tfstate`
- tabela DynamoDB para lock

Rode apenas uma vez por conta/região.

```powershell
cd "$ROOT\terraform-backend"

terraform init
terraform plan
terraform apply
```

O bucket configurado atualmente é:

```text
oficina-terraform-state-376854726751-us-east-1
```

Se esse bucket já existir em outra conta, altere `state_bucket_name` em `terraform-backend/variables.tf` e atualize o mesmo nome nos blocos `backend "s3"` dos módulos:

- `infra-geral-oficina/main.tf`
- `infra-database/main.tf`
- `lambda-auth-oficina/terraform/main.tf`

## 2. Inicializar os módulos Terraform

Depois que o backend remoto existir, inicialize cada módulo.

```powershell
cd "$ROOT\infra-geral-oficina"
terraform init

cd "$ROOT\infra-database"
terraform init

cd "$ROOT\lambda-auth-oficina\terraform"
terraform init
```

Se houver state local antigo com recursos reais, use:

```powershell
terraform init -migrate-state
```

Antes de qualquer `apply`, confira:

```powershell
terraform state list
terraform plan
```

Se o state estiver vazio, é esperado que o `plan` mostre recursos para criar.

## 3. Criar a infra base: VPC, EKS e ECR

Não rode `terraform apply` completo no `infra-geral-oficina` neste momento. A API depende do `rds_address`, que ainda não existe.

Rode apenas o apply parcial:

```powershell
cd "$ROOT\infra-geral-oficina"

terraform apply `
  -target=aws_vpc.main `
  -target=aws_subnet.public `
  -target=aws_subnet.private `
  -target=aws_internet_gateway.main `
  -target=aws_nat_gateway.main `
  -target=aws_route_table.public `
  -target=aws_route_table.private `
  -target=aws_route_table_association.public `
  -target=aws_route_table_association.private `
  -target=aws_security_group.eks_nodes `
  -target=aws_eks_cluster.main `
  -target=aws_eks_node_group.main `
  -target=aws_ecr_repository.api
```

Depois, pegue os outputs:

```powershell
terraform output
```

Guarde estes valores:

- `vpc_id`
- `private_subnet_ids`
- `eks_cluster_security_group_id`
- `eks_nodes_security_group_id`
- `ecr_repository_url`
- `kubeconfig_command`

Configure o `kubectl` para acessar o EKS:

```powershell
aws eks update-kubeconfig --region us-east-1 --name oficina-eks
```

## 4. Criar o RDS PostgreSQL

Crie ou atualize `infra-database/terraform.tfvars` com os outputs do passo anterior.

Exemplo:

```hcl
aws_region   = "us-east-1"
project_name = "oficina"

vpc_id                        = "vpc-xxxxxxxx"
private_subnet_ids            = ["subnet-xxxxxxxx", "subnet-yyyyyyyy"]
eks_cluster_security_group_id = "sg-xxxxxxxx"
eks_nodes_security_group_id   = "sg-yyyyyyyy"

db_name     = "oficina"
db_user     = "oficina"
db_password = "troque-por-uma-senha-segura"

db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_engine_version    = "16.13"
restore_from_dump    = false
```

Depois aplique:

```powershell
cd "$ROOT\infra-database"

terraform plan
terraform apply
```

Ao final, pegue o endpoint do banco:

```powershell
terraform output rds_address
```

Esse valor será usado no próximo passo.

## 5. Subir a API no EKS

Atualize `infra-geral-oficina/terraform.tfvars` com o `rds_address` gerado pelo módulo do banco.

Exemplo:

```hcl
aws_region             = "us-east-1"
project_name           = "oficina"
db_name                = "oficina"
db_user                = "oficina"
db_password            = "troque-por-uma-senha-segura"
jwt_secret             = "troque-por-uma-chave-jwt-com-pelo-menos-256-bits"
eks_node_instance_type = "t3.small"
eks_node_desired       = 1
eks_node_min           = 1
eks_node_max           = 2

rds_address = "oficina-postgres.xxxxx.us-east-1.rds.amazonaws.com"
```

Antes de aplicar, garanta que a imagem da API existe no registry usado pelo deployment.

O Terraform em `infra-geral-oficina/k8s-resources.tf` aponta para o ECR criado pelo módulo:

```text
aws_ecr_repository.api.repository_url:latest
```

Faça build e push da imagem para o ECR:

```powershell
cd "$ROOT\oficina-api\oficina-api"

$ECR_URL = "<valor de ecr_repository_url>"

aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URL
docker build -t oficina-api .
docker tag oficina-api:latest "$ECR_URL`:latest"
docker push "$ECR_URL`:latest"
```

Depois aplique o restante da infra geral:

```powershell
cd "$ROOT\infra-geral-oficina"

terraform plan
terraform apply
```

Esse apply cria:

- namespace Kubernetes
- ConfigMap com `DB_HOST = rds_address`
- Secret com credenciais do banco e JWT
- Mailpit
- Deployment da API
- Service LoadBalancer
- HPA

A API só ficará pronta quando o health check responder:

```text
/api/v1/actuator/health/readiness
```

## 6. Validar a API

Veja os pods:

```powershell
kubectl get pods -n oficina
```

Veja o serviço público:

```powershell
kubectl get svc -n oficina
```

Ou use o output do Terraform:

```powershell
cd "$ROOT\infra-geral-oficina"
terraform output api_load_balancer_hostname
```

Swagger:

```text
http://<load-balancer-hostname>/api/v1/swagger-ui/index.html
```

## 7. Subir a Lambda de autenticação

Crie ou atualize `lambda-auth-oficina/terraform/terraform.tfvars`.

Exemplo:

```hcl
vpc_id             = "vpc-xxxxxxxx"
private_subnet_ids = ["subnet-xxxxxxxx", "subnet-yyyyyyyy"]

db_host     = "oficina-postgres.xxxxx.us-east-1.rds.amazonaws.com"
db_name     = "oficina"
db_user     = "oficina"
db_password = "troque-por-uma-senha-segura"

jwt_secret = "mesma-chave-jwt-usada-na-api"

rds_security_group_id = "sg-do-rds"
```

Depois aplique:

```powershell
cd "$ROOT\lambda-auth-oficina\terraform"

terraform plan
terraform apply
```

Pegue os endpoints:

```powershell
terraform output
```

## Ordem resumida

```text
1. terraform-backend
2. infra-geral-oficina parcial: VPC + EKS + ECR
3. infra-database: RDS PostgreSQL
4. build/push da imagem da API
5. infra-geral-oficina completo: Kubernetes + API
6. lambda-auth-oficina/terraform: Lambda + API Gateway
```

## Pontos de atenção

- Não rode `terraform apply` completo em `infra-geral-oficina` antes de criar o RDS.
- Não commite `terraform.tfstate`, `terraform.tfstate.backup` ou `terraform.tfvars`.
- `terraform-backend` normalmente é aplicado uma vez por conta/região.
- Se `terraform plan` indicar recriação de VPC, EKS, RDS ou Lambda em ambiente existente, pare e investigue o state antes de aplicar.
- O `jwt_secret` da API e da Lambda deve ser o mesmo.
- O RDS fica em subnets privadas; acesso direto da máquina local pode não funcionar.
- Se estiver usando AWS Academy/Learner Lab, lembre de renovar `AWS_SESSION_TOKEN` quando expirar.

## Destruição da infraestrutura

Para **parar custos** (EKS, RDS, etc.) enquanto não usa o lab, destrua os módulos abaixo.
O `terraform-backend` (S3 + DynamoDB) **não** precisa ser destruído — mantém o state para recriar depois.

Se você usa o **monorepo local** com a pasta `scripts/`, após renovar credenciais do Academy:

```powershell
cd "$ROOT\scripts"
.\teardown-aws.ps1
```

Para destruir tudo manualmente, siga a ordem inversa:

```powershell
cd "$ROOT\lambda-auth-oficina\terraform"
terraform destroy

cd "$ROOT\infra-geral-oficina"
terraform destroy

cd "$ROOT\infra-database"
terraform destroy
```

Se o RDS não puder ser destruído porque ainda há dependências de rede, remova primeiro os recursos Kubernetes/LoadBalancer no `infra-geral-oficina`.

O `terraform-backend` deve ser destruído por último e apenas se você não precisar mais dos states remotos.
