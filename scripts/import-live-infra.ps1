<#
.SYNOPSIS
    Importa infra AWS existente (VPC vpc-07f0f2c2...) para o Terraform state local.

.DESCRIPTION
    Use quando terraform.tfstate.backup apontar para VPC antiga (vpc-01a15299...).
    Requer lab AWS ativo (aws sts get-caller-identity OK).

.EXAMPLE
    cd infra-geral-oficina
    .\scripts\import-live-infra.ps1 -DiscoverOnly
    .\scripts\import-live-infra.ps1
#>
[CmdletBinding()]
param(
    [switch]$DiscoverOnly,
    [switch]$SkipKubernetesHint
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

# --- IDs confirmados (EKS describe-cluster) ---
$VpcId = "vpc-07f0f2c2ac01c4444"
$PublicSubnet0 = "subnet-0d3358bc9938109a0"
$PublicSubnet1 = "subnet-0f0c2ad679f1b36f3"
$PrivateRds0 = "subnet-0ceb1464e2807d965"
$PrivateRds1 = "subnet-03717cb3f775284e3"
$EksClusterSg = "sg-0dce5ad4fd3e4a12d"
$EksNodesSg = "sg-0ffbcd310357e160a"

Write-Host "==> Conta AWS" -ForegroundColor Cyan
aws sts get-caller-identity | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Credenciais invalidas ou lab expirado (voc-cancel-cred). Renove no AWS Academy."
}

Write-Host "`n==> Subnets na VPC $VpcId" -ForegroundColor Cyan
$subnets = aws ec2 describe-subnets `
    --filters "Name=vpc-id,Values=$VpcId" `
    --region us-east-1 `
    --query "Subnets[*].{Id:SubnetId,Cidr:CidrBlock,Az:AvailabilityZone,Name:Tags[?Key=='Name'].Value|[0]}" `
    --output json | ConvertFrom-Json
$subnets | Format-Table -AutoSize

# Subnets legadas private[0]/[1] (CIDR 10.0.10.0/24 e 10.0.11.0/24) — preencha se existirem
$PrivateSubnet0 = ($subnets | Where-Object { $_.Cidr -eq "10.0.10.0/24" }).Id
$PrivateSubnet1 = ($subnets | Where-Object { $_.Cidr -eq "10.0.11.0/24" }).Id

Write-Host "`n==> IGW / Route table" -ForegroundColor Cyan
aws ec2 describe-internet-gateways `
    --filters "Name=attachment.vpc-id,Values=$VpcId" `
    --region us-east-1 `
    --query "InternetGateways[*].InternetGatewayId" --output text | Out-Host
aws ec2 describe-route-tables `
    --filters "Name=vpc-id,Values=$VpcId" `
    --region us-east-1 `
    --query "RouteTables[*].{Id:RouteTableId,Main:Associations[?Main==\`true\`].Main|[0],Subnet:Associations[?SubnetId!=null].SubnetId}" `
    --output json | Out-Host

if ($DiscoverOnly) {
    Write-Host "`nAjuste PrivateSubnet0/1 no script se os CIDRs forem diferentes. Depois rode sem -DiscoverOnly." -ForegroundColor Yellow
    exit 0
}

if (-not (Test-Path "terraform.tfvars")) {
    throw "Crie terraform.tfvars antes (copie de terraform.tfvars.example)."
}

# Backup state antigo
if (Test-Path "terraform.tfstate") {
    $stamp = Get-Date -Format "yyyyMMddHHmmss"
    Copy-Item "terraform.tfstate" "terraform.tfstate.before-import.$stamp" -Force
    Write-Host "Backup: terraform.tfstate.before-import.$stamp" -ForegroundColor DarkGray
}

if (Test-Path "backend_s3.tf") {
    Rename-Item "backend_s3.tf" "backend_s3.tf.disabled" -Force
}
Remove-Item -Recurse -Force .terraform -ErrorAction SilentlyContinue
terraform init -upgrade -input=false -reconfigure | Out-Host
if ($LASTEXITCODE -ne 0) { throw "terraform init falhou" }

function Invoke-TfImport([string]$Address, [string]$Id) {
    Write-Host "terraform import $Address $Id" -ForegroundColor Cyan
    terraform import $Address $Id
    if ($LASTEXITCODE -ne 0) { throw "Import falhou: $Address" }
}

# Ordem: VPC -> rede -> SG -> EKS -> ECR
Invoke-TfImport "aws_vpc.main" $VpcId

$igw = (aws ec2 describe-internet-gateways `
    --filters "Name=attachment.vpc-id,Values=$VpcId" `
    --region us-east-1 `
    --query "InternetGateways[0].InternetGatewayId" --output text).Trim()
if ($igw -and $igw -ne "None") {
    Invoke-TfImport "aws_internet_gateway.main" $igw
}

Invoke-TfImport "aws_subnet.public[0]" $PublicSubnet0
Invoke-TfImport "aws_subnet.public[1]" $PublicSubnet1

if ($PrivateSubnet0) { Invoke-TfImport "aws_subnet.private[0]" $PrivateSubnet0 }
else { Write-Host "AVISO: subnet private[0] (10.0.10.0/24) nao encontrada — import manual se existir." -ForegroundColor Yellow }

if ($PrivateSubnet1) { Invoke-TfImport "aws_subnet.private[1]" $PrivateSubnet1 }
else { Write-Host "AVISO: subnet private[1] (10.0.11.0/24) nao encontrada — import manual se existir." -ForegroundColor Yellow }

Invoke-TfImport "aws_subnet.private_rds[0]" $PrivateRds0
Invoke-TfImport "aws_subnet.private_rds[1]" $PrivateRds1

# Route table publica (com rota 0.0.0.0/0 -> IGW)
$rts = aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VpcId" --region us-east-1 --output json | ConvertFrom-Json
$publicRt = $rts.RouteTables | Where-Object {
    ($_.Routes | Where-Object { $_.DestinationCidrBlock -eq "0.0.0.0/0" -and $_.GatewayId -like "igw-*" })
} | Select-Object -First 1
if ($publicRt) {
    Invoke-TfImport "aws_route_table.public" $publicRt.RouteTableId
    terraform import "aws_route_table_association.public[0]" "$PublicSubnet0/$($publicRt.RouteTableId)"
    if ($LASTEXITCODE -ne 0) { throw "Import falhou: aws_route_table_association.public[0]" }
    terraform import "aws_route_table_association.public[1]" "$PublicSubnet1/$($publicRt.RouteTableId)"
    if ($LASTEXITCODE -ne 0) { throw "Import falhou: aws_route_table_association.public[1]" }
}

Invoke-TfImport "aws_security_group.eks_cluster" $EksClusterSg
Invoke-TfImport "aws_security_group.eks_nodes" $EksNodesSg
Invoke-TfImport "aws_eks_cluster.main" "oficina-eks"
Invoke-TfImport "aws_eks_node_group.main" "oficina-eks:oficina-nodes"
Invoke-TfImport "aws_ecr_repository.api" "oficina-api"

Write-Host "`n==> terraform plan" -ForegroundColor Cyan
terraform plan -input=false

if (-not $SkipKubernetesHint) {
    Write-Host @"

Proximo passo:
  - Se o plan mostrar apenas recursos kubernetes_* (add/change), avalie: terraform apply
  - Se mostrar destroy em VPC/EKS: PARE e rode -DiscoverOnly de novo
  - Commite terraform.tfstate quando plan tiver 0 destroy

"@ -ForegroundColor Yellow
}
