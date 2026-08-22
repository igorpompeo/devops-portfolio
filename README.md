# DevOps Portfolio

Repositório de estudos práticos e projetos aplicados na trilha DevOps —
infraestrutura como código, cloud (AWS e OCI), e GitOps.

Cada módulo documenta não só "como rodar", mas as decisões técnicas por
trás de cada escolha.

## Módulos

| # | Módulo | Status | Descrição |
|---|--------|--------|-----------|
| 01 | [Fundamentos AWS](./01-fundamentos-aws) | ✅ Completo | VPC, EC2, IAM/MFA, Security Groups — provisionamento manual como base para IaC |
| 02 | [CloudFormation](./02-cloudformation) | ✅ Completo | Template do zero, debugging real (`!Ref` vs `!GetAtt`), deploy via AWS CLI |
| 03 | [GitOps (Argo CD)](./03-gitops) | ✅ Completo | Sync policies, drift e self-healing testados na prática, exposição direta em projeto de cliente |
| 04 | [Terraform (OCI)](./04-terraform-oci) | 🚧 Em andamento | IaC multi-cloud — rede provisionada; cluster Kubernetes gerenciado (OKE) em progresso |
| 05 | CI/CD completo | 🔜 Planejado | Pipeline que builda imagem, publica no registry, e atualiza o Git automaticamente |
| 06 | GitOps avançado | 🔜 Planejado | Multi-ambiente (dev/staging/prod), Helm/Kustomize, ApplicationSets |

## Sobre

Estudando para transição/entrada em DevOps. Background prévio em Git/GitHub
como Release Manager, aplicando esse conhecimento agora à infraestrutura.

## Contato

[Igor Pompeo Tavares de Souza] — [[LinkedIn](https://www.linkedin.com/in/igor-pompeo-679636b2/)] — [Email](pompbass@gmail.com)