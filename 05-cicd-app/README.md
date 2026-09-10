# Módulo 05 — CI/CD Completo (Go + Docker + GitHub Actions)

## Objetivo

Construir um pipeline de CI/CD completo, do commit ao deploy: uma aplicação
containerizada, testada automaticamente, publicada num registry de imagens, e
implantada num cluster Kubernetes — sem nenhum passo manual entre "código
pronto" e "imagem disponível para deploy".

## Por que uma aplicação nova em vez de reaproveitar algo existente

Não havia uma aplicação própria no portfólio até este módulo. Em vez de usar
um exemplo genérico de tutorial, foi criada uma aplicação mínima (um servidor
HTTP com endpoint `/health`) — pequena o suficiente para não competir pela
atenção com o objetivo real do módulo (o pipeline), mas real o suficiente
para ter testes automatizados de verdade e uma imagem Docker de verdade. O
endpoint `/health` também não é arbitrário: é o mesmo padrão que o Kubernetes
usa para liveness/readiness probes, o que conecta diretamente com o Módulo 06.

## Decisões técnicas

### Linguagem: Go

Escolhida apesar de familiaridade baixa, por uma razão técnica específica: Go
compila para um binário estático único, sem depender de um runtime externo
instalado na imagem final (diferente de Python, que exige o interpretador e
bibliotecas presentes no container). Isso viabiliza o uso de `FROM scratch`
no Dockerfile — uma imagem final praticamente vazia, contendo apenas o
binário compilado.

### Dockerfile multi-stage

O build usa dois estágios: um com a toolchain completa do Go
(`golang:1.27-alpine`) apenas para compilar; outro partindo de `scratch`,
que recebe só o binário já compilado do primeiro estágio. A imagem de build
(~300MB+) nunca é publicada — só o resultado final, testado em
`13.5MB` de disco / `4.9MB` de conteúdo, uma redução de mais de 95%.

Duas configurações são obrigatórias para viabilizar `scratch`:
- `CGO_ENABLED=0` no `go build`: desativa a possibilidade do binário depender
  de bibliotecas C do sistema operacional, que não existem numa imagem vazia.
- `node_source_details`/imagem base compatível com a arquitetura de destino
  (ver seção de erros, aplicável ao Terraform do Módulo 04, não a este
  módulo — mencionado aqui apenas como paralelo conceitual).

### Registry: GitHub Container Registry (ghcr.io)

Escolhido em vez de Docker Hub porque o pipeline já roda no GitHub Actions,
o que permite autenticação nativa via `GITHUB_TOKEN` — uma credencial gerada
automaticamente a cada execução, com escopo limitado ao repositório e vida
útil restrita à duração do workflow (expira ao final da execução). Isso evita
a necessidade de gerar e armazenar um token pessoal de longa duração como
secret, reduzindo a superfície de risco em caso de vazamento.

### Pipeline dividido em dois jobs (`test` e `build-and-push`)

Em vez de um job único, o workflow separa teste de build/publish, conectados
por `needs: test`. Isso garante que uma imagem só é publicada se os testes
passarem — evitando publicar uma imagem com código quebrado no registry.
Como jobs do GitHub Actions rodam em runners isolados (sem estado
compartilhado), o segundo job repete o `checkout`, mas não repete a
instalação do Go, já que não executa código Go diretamente, apenas builda a
imagem via Docker.

### Gatilho por pasta, não por extensão de arquivo

O workflow dispara em qualquer mudança dentro de `05-cicd-app/**`, não
apenas em arquivos `.go`. A razão: uma mudança no `Dockerfile` ou no
`go.mod` também deveria disparar o pipeline (o resultado da build muda),
mesmo sem nenhum arquivo `.go` ter sido tocado. Filtrar por pasta captura
qualquer alteração que afete o artefato final; filtrar por extensão não.

## O que foi feito

1. Aplicação Go (`main.go`) com servidor HTTP e rota `/health`
2. Teste automatizado (`main_test.go`) usando `net/http/httptest`, sem
   necessidade de subir um servidor real na porta 8080
3. `Dockerfile` multi-stage, build final baseado em `scratch`
4. Build e teste local via `docker build` / `docker run`, validado com `curl`
5. Workflow do GitHub Actions (`.github/workflows/cicd-app.yml`) com dois
   jobs: `test` (roda `go test ./...`) e `build-and-push` (builda e publica
   a imagem no `ghcr.io`, condicionado ao sucesso do `test`)
6. Permissões explícitas (`packages: write`) declaradas no job de
   publish, para não depender da configuração padrão do repositório
7. Visibilidade do pacote alterada manualmente para pública no GHCR (nasce
   privada por padrão, mesmo em repositório público)
8. Deploy manual no cluster `kind` (Módulo 03) via `kubectl apply`, puxando
   a imagem publicada — pod confirmado `Running`

## Erros e soluções

### Conflito de nome de container ao testar localmente

docker: Error response from daemon: Conflict. The container name
"/teste-app" is already in use...

**Causa raiz:** nomes de container no Docker precisam ser únicos entre
containers parados *ou* rodando, não só entre os ativos no momento. Um
container de teste anterior, já parado, ainda ocupava o nome.

**Solução:** `docker rm teste-app` antes de rodar novamente, ou usar um nome
diferente a cada teste descartável.

### Workflow não disparou na própria criação

Ao criar o arquivo `.github/workflows/cicd-app.yml` e commitá-lo, a aba
Actions mostrou "0 workflow runs" — nenhuma execução, mesmo o workflow
aparecendo corretamente cadastrado no GitHub.

**Causa raiz:** o gatilho `paths: ['05-cicd-app/**']` avalia quais arquivos
mudaram no push. O arquivo do workflow em si vive em `.github/workflows/`,
fora da pasta monitorada — logo, criá-lo não conta como uma mudança dentro
de `05-cicd-app/`, e o próprio gatilho não disparou para si mesmo.

**Solução:** um commit subsequente tocando algo dentro de `05-cicd-app/`
(neste caso, a criação de um `.gitignore` para o binário compilado
localmente) disparou a primeira execução.

### Erro de indentação no manifest do Kubernetes

Error from server (BadRequest): error when creating
"05-cicd-app/k8s/deployment.yaml": Deployment in version "v1" cannot be
handled as a Deployment: strict decoding error: unknown field
"spec.template.metadata.spec"

**Causa raiz:** o bloco `spec:` do container ficou indentado como filho de
`metadata:` em vez de irmão dele dentro de `template:` — um erro de
indentação de poucos espaços, mas suficiente para o YAML ser interpretado
com uma estrutura completamente diferente da pretendida.

**Solução:** reescrita do manifest garantindo que `metadata:` e `spec:`
dentro de `template:` compartilhem exatamente a mesma indentação.

## Estrutura

05-cicd-app/
├── go.mod
├── main.go
├── main_test.go
├── Dockerfile
├── .gitignore
└── k8s/
└── deployment.yaml

.github/workflows/
└── cicd-app.yml

## Como reproduzir

Pré-requisitos: Go 1.27+, Docker, `kubectl` configurado com um contexto
válido (`kind` ou outro cluster), conta GitHub com Actions habilitado.

```bash
cd 05-cicd-app

# testar localmente
go test ./...
go run main.go        # em outro terminal: curl localhost:8080/health

# build e teste da imagem
docker build -t 05-cicd-app:local .
docker run -d -p 8080:8080 --name teste-app 05-cicd-app:local
curl localhost:8080/health
docker rm -f teste-app
```

O pipeline de CI/CD dispara automaticamente a cada push na `main` que
altere algo dentro de `05-cicd-app/`. Após a primeira publicação, a
visibilidade do pacote precisa ser ajustada manualmente para pública em
GitHub → Packages → `05-cicd-app` → Package settings.

Deploy manual (antes do GitOps do Módulo 06 assumir isso):

```bash
kubectl config use-context kind-devops-portfolio
kubectl apply -f 05-cicd-app/k8s/deployment.yaml
kubectl get pods
```

## Próximos passos

Módulo 06 — conectar este deploy ao Argo CD (já rodando desde o Módulo 03),
substituindo o `kubectl apply` manual por sincronização GitOps automática,
com suporte a múltiplos ambientes via Helm ou Kustomize.