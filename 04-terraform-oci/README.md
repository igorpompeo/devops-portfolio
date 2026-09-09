# Módulo 04 — Infraestrutura como Código com Terraform (OCI)

## Objetivo

Provisionar infraestrutura de nuvem real usando Terraform, aprofundando o
conceito de IaC já visto no Módulo 02 (CloudFormation) — agora numa ferramenta
multi-cloud, com gestão de estado explícita, e um novo provedor: Oracle Cloud
Infrastructure (OCI). Esta etapa cobre a camada de rede e um cluster
Kubernetes gerenciado (OKE) provisionado sobre ela.

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

### Camada de rede

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

### Cluster OKE

- **Kubernetes `v1.34.10`, CNI `FLANNEL_OVERLAY`.** A versão foi escolhida no
  meio da lista de versões disponíveis (não a mais nova, `v1.36.1`; nem uma
  antiga) — patch mais alto dentro de uma minor estável, priorizando
  maturidade sobre "última versão" para um cluster de estudo. O CNI Flannel
  (overlay) foi escolhido em vez do `OCI_VCN_IP_NATIVE` porque este projeto
  não precisa de escalonamento de pods a ponto de esgotar os ~251 IPs
  utilizáveis da subnet privada (`/24`) — Flannel isola os IPs dos pods numa
  rede virtual própria, sem consumir espaço de endereçamento da VCN.
- **Node pool dimensionado para metade da cota Always Free disponível
  (`1 OCPU` / `6 GB RAM`), não o total.** A cota Always Free de instâncias
  ARM (Ampere A1) da OCI foi reduzida pela própria Oracle de 4 OCPUs/24GB para
  2 OCPUs/12GB em meados de 2026, sem aviso público — só a documentação foi
  atualizada. Provisionar a cota inteira num único node deixaria zero margem
  para qualquer outro recurso ARM na conta; usar metade mantém headroom.
- **`node_source_details` aponta para uma imagem Oracle Linux específica**
  (`Oracle-Linux-9.8-aarch64-...-OKE-1.34.10-...`), não uma imagem genérica.
  Imagens de node do OKE vêm pré-casadas com arquitetura (`aarch64`, por ser
  ARM) e versão do Kubernetes — usar a imagem errada (ex: uma sem `aarch64`,
  ou casada com outra versão do K8s) falha a criação do node pool.

## O que foi feito

1. VCN (`10.0.0.0/16`) criada na região `eu-frankfurt-1`
2. Subnet pública (`10.0.0.0/24`) e subnet privada (`10.0.1.0/24`)
3. Internet Gateway (tráfego bidirecional, subnet pública)
4. NAT Gateway (tráfego de saída, subnet privada)
5. Service Gateway (acesso privado a serviços OCI, sem passar pela internet
   pública)
6. Route tables e security lists associadas a cada subnet
7. Cluster OKE (`v1.34.10`, control plane "basic", endpoint público na subnet
   pública)
8. Node pool ARM (`VM.Standard.A1.Flex`, 1 OCPU / 6GB, 1 node na subnet
   privada)
9. `terraform apply` executado com sucesso — cluster `ACTIVE`, node `Ready`
   confirmado via `kubectl get nodes`
10. Kubeconfig gerado via `oci ce cluster create-kubeconfig` e mesclado ao
    `~/.kube/config` existente (coexistindo com o contexto do cluster `kind`
    do Módulo 03)

## Erros e soluções

### `Error: 400-InvalidParameter, Invalid nodeSourceDetails`

**Causa raiz:** o recurso `oci_containerengine_node_pool` foi escrito sem o
bloco `node_source_details`, que informa qual imagem de sistema operacional
os worker nodes devem usar ao bootar. Diferente do control plane (gerenciado
inteiramente pela Oracle, sem VMs visíveis), o node pool cria VMs reais que
precisam de uma imagem — e o Terraform não assume um padrão sozinho.

**Solução:**
```bash
oci ce node-pool-options get --node-pool-option-id all \
  --compartment-id <compartment_ocid>
```
Esse comando lista as imagens disponíveis (campo `sources`). É necessário
escolher a que combina arquitetura (`aarch64`, para ARM) e versão do
Kubernetes (`OKE-1.34.10`, batendo com o `kubernetes_version` do cluster) —
usar uma imagem x86 ou casada com outra versão do K8s reproduz o mesmo erro.

```hcl
node_source_details {
  image_id    = "ocid1.image.oc1.eu-frankfurt-1.aaaa..."
  source_type = "IMAGE"
}
```

## Estrutura
04-terraform-oci/
├── providers.tf
├── variables.tf
├── main.tf
├── outputs.tf
├── terraform.tfvars.example
└── terraform.tfvars (local, nunca commitado)

## Como reproduzir

Pré-requisitos: Terraform instalado, OCI CLI configurado (`oci setup config`),
um compartment OCI já criado (ver seção de decisões técnicas).

```bash
cd 04-terraform-oci
cp terraform.tfvars.example terraform.tfvars
# edite terraform.tfvars com o OCID do seu compartment e tenancy

terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Após o apply, gere o kubeconfig e confirme o cluster:

```bash
oci ce cluster create-kubeconfig \
  --cluster-id <oke_cluster_id do output> \
  --file $HOME/.kube/config \
  --region eu-frankfurt-1 \
  --token-version 2.0.0

kubectl config use-context <contexto gerado>
kubectl get nodes
```

Criação do cluster costuma levar de 5 a 10 minutos até o node aparecer
`Ready`.

## Próximos passos

Módulo 05 — pipeline CI/CD completo, publicando imagens/manifests que o
Módulo 06 (GitOps avançado, multi-env com ApplicationSets) vai consumir via
Argo CD, sincronizando neste mesmo cluster OKE.