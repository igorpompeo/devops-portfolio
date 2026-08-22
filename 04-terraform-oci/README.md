# Módulo 04 — Infraestrutura como Código com Terraform (OCI)

## Objetivo

Provisionar infraestrutura de nuvem real usando Terraform, aprofundando o
conceito de IaC já visto no Módulo 02 (CloudFormation) — agora numa ferramenta
multi-cloud, com gestão de estado explícita, e um novo provedor: Oracle Cloud
Infrastructure (OCI). Esta etapa cobre a camada de rede, base para o cluster
Kubernetes gerenciado (OKE) do próximo passo.

## Por que OCI em vez de AWS/EKS

O objetivo original era provisionar um cluster Kubernetes gerenciado (EKS) via
Terraform. A OCI foi escolhida no lugar por oferecer um tier **Always Free**
genuíno — não um trial de 30 dias — que inclui o control plane do OKE
(Kubernetes gerenciado da Oracle) sem custo e computação ARM suficiente para os
worker nodes, também sem custo. Isso permite treinar Terraform provisionando
infraestrutura gerenciada de verdade (não um cluster local tipo `kind`) sem
nenhum risco financeiro. Como efeito colateral, o portfólio passa a demonstrar
Terraform em mais de uma cloud, não só decorando comandos de uma ferramenta
específica.

## Decisões técnicas

- **Compartment criado manualmente, fora do Terraform.** Compartments são
  fundamentais e raramente recriados — não queremos que um `terraform destroy`
  acidental tenha poder de apagar a estrutura organizacional que contém tudo.
  Mesmo princípio de "quem provisiona o provisionador" que existe em qualquer
  bootstrap de infraestrutura.
- **Arquitetura de rede pública/privada**, espelhando o VPC manual do Módulo
  01: subnet pública hospeda o endpoint da API do Kubernetes e o Load
  Balancer; subnet privada hospeda os worker nodes, sem IP público direto.
- **Credenciais via `config_file_profile`**, reaproveitando o `~/.oci/config`
  já configurado pelo `oci setup config` — nenhum OCID, fingerprint ou chave
  privada duplicado no código Terraform.
- **`.gitignore` na raiz do repositório**, não dentro da pasta do módulo — os
  padrões (`*.tfstate`, `.terraform/`) se aplicam em cascata a qualquer
  subpasta, então um único arquivo cobre todos os módulos Terraform presentes
  e futuros.
- **`.terraform.lock.hcl` é commitado**, ao contrário do resto de
  `.terraform/`. Ele trava a versão exata do provider usado, evitando
  divergência de comportamento entre máquinas diferentes rodando este código.
- **Security Lists propositalmente simplificadas** para este estágio de
  aprendizado (tráfego interno liberado para toda a VCN). Um ambiente de
  produção real restringiria isso às portas específicas exigidas pelo OKE
  (documentadas pela Oracle), não à VCN inteira.

## O que foi feito

1. VCN (`10.0.0.0/16`) criada na região `eu-frankfurt-1`
2. Subnet pública (`10.0.0.0/24`) e subnet privada (`10.0.1.0/24`)
3. Internet Gateway (tráfego bidirecional, subnet pública)
4. NAT Gateway (tráfego de saída, subnet privada)
5. Service Gateway (acesso privado a serviços OCI, sem passar pela internet
   pública)
6. Route tables e security lists associadas a cada subnet
7. `terraform plan` e `terraform apply` executados com sucesso — 10 recursos
   criados, sem custo (rede não é cobrada na OCI; apenas compute e alguns
   serviços gerenciados são)

## Estrutura

```
04-terraform-oci/
├── providers.tf
├── variables.tf
├── main.tf
├── outputs.tf
├── terraform.tfvars.example
└── terraform.tfvars        (local, nunca commitado)
```

## Como reproduzir

Pré-requisitos: Terraform instalado, OCI CLI configurado (`oci setup config`),
um compartment OCI já criado (ver seção de decisões técnicas).

```bash
cd 04-terraform-oci
cp terraform.tfvars.example terraform.tfvars
# edite terraform.tfvars com o OCID do seu compartment

terraform init
terraform plan
terraform apply
```

## Próximos passos

Cluster OKE (control plane "basic", gratuito) e node pool ARM dentro do limite
Always Free, usando os outputs `public_subnet_id` e `private_subnet_id` gerados
aqui.