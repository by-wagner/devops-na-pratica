# DevOps na Prática — API de tarefas com CI/CD, containers e AWS

![CI](https://github.com/by-wagner/devops-na-pratica/actions/workflows/ci.yml/badge.svg)

Projeto da disciplina **DevOps na Prática (PUCRS Online)**. Uma API REST simples de lista de tarefas serve de base
para a esteira DevOps completa:

- **Fase 1:** Integração Contínua (CI) com GitHub Actions e Infraestrutura como Código (IaC) com Terraform
  (estado entregue marcado com a tag [`fase-1`](https://github.com/by-wagner/devops-na-pratica/tree/fase-1)).
- **Fase 2:** Entrega Contínua (CD), Docker, orquestração com Kubernetes e deploy automático na AWS.

## Estrutura

```
.
├── .github/workflows/ci.yml   # pipeline de CI/CD
├── src/                       # API (Node.js, sem dependências de produção)
├── test/                      # testes automatizados (node:test)
├── Dockerfile                 # imagem da API (Node 24 Alpine, sem root, healthcheck)
├── compose.yaml               # sobe a API em container com um comando
├── k8s/                       # manifests do Kubernetes (Deployment com 2 réplicas + Service)
├── scripts/
│   ├── deploy.sh              # deploy/rollback na EC2 via AWS SSM + smoke test
│   └── k8s-deploy.sh          # deploy no Kubernetes: rolling update, autocura e smoke test
└── infra/                     # Terraform (AWS): VPC, sub-rede, security group e EC2 com Docker
```

## API

| Método | Rota      | Descrição                      | Respostas |
| ------ | --------- | ------------------------------ | --------- |
| GET    | `/health` | Verificação de saúde           | 200       |
| GET    | `/tasks`  | Lista as tarefas               | 200       |
| POST   | `/tasks`  | Cria tarefa `{"title": "..."}` | 201, 400  |

## Rodando localmente

Requisito: Node.js 22 ou superior.

```bash
npm ci                # instala as dependências de desenvolvimento
npm run lint          # ESLint (erros e más práticas)
npm run format:check  # Prettier (formatação)
npm test              # testes automatizados
npm run build         # gera o pacote em dist/
npm start             # sobe a API em http://localhost:3000
```

### Em container

```bash
docker compose up -d --build   # constrói a imagem e sobe a API
curl localhost:3000/health     # {"status":"ok"}
docker compose down
```

## Pipeline de CI/CD

Executa em todo `push` e `pull request` para `main` (e manualmente pela aba **Actions**):

| Job                    | Quando                                     | O que faz                                                                                                                                                 |
| ---------------------- | ------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **app** (Node 22 e 24) | sempre                                     | `npm ci` → ESLint → Prettier → testes → build → artefato `.tgz`                                                                                           |
| **infra**              | sempre                                     | `terraform fmt -check` → `init` → `validate`                                                                                                              |
| **image**              | depois de app e infra                      | constrói a imagem Docker e faz smoke test do container; na `main`, publica no GHCR com as tags do SHA e `latest`                                          |
| **kubernetes**         | depois de app e infra                      | sobe um cluster **kind**, aplica `k8s/`, faz rolling update para a imagem do commit, apaga um pod para provar a autocura e testa o `/health` pelo Service |
| **deploy**             | só na `main`, depois de image e kubernetes | troca o container na EC2 pela imagem do commit (via AWS SSM) e só conclui se o `/health` responder 200                                                    |

Qualquer falha deixa o pipeline vermelho e impede a etapa seguinte; a versão em produção só muda se tudo antes passou.

Imagem publicada: [`ghcr.io/by-wagner/devops-na-pratica`](https://github.com/by-wagner/devops-na-pratica/pkgs/container/devops-na-pratica).

## Orquestração (Kubernetes)

`k8s/deployment.yaml` mantém **2 réplicas** da API com:

- **readinessProbe** e **livenessProbe** no `/health`: o pod só recebe tráfego quando está pronto e é reiniciado se parar de responder;
- **rolling update** com `maxUnavailable: 0`: a troca de versão nunca reduz as réplicas prontas;
- limites de CPU/memória e container sem root, sem escalonamento de privilégio e com sistema de arquivos somente leitura.

Para rodar num cluster local (ex.: [kind](https://kind.sigs.k8s.io/)):

```bash
kind create cluster
docker build -t devops-na-pratica:local . && kind load docker-image devops-na-pratica:local
scripts/k8s-deploy.sh devops-na-pratica:local
```

## Deploy na AWS (AWS Academy Learner Lab)

1. **Credenciais:** inicie o lab, copie as credenciais de _AWS Details_ para um perfil `academy` em `~/.aws/credentials`
   e atualize os secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e `AWS_SESSION_TOKEN` do repositório
   (expiram a cada sessão do lab).
2. **Infraestrutura:**
   ```bash
   cd infra
   AWS_PROFILE=academy terraform apply    # VPC, sub-rede, security group e EC2 t3.micro com Docker
   AWS_PROFILE=academy terraform destroy  # remove tudo ao terminar, para não gastar créditos
   ```
   A EC2 usa o `LabInstanceProfile` do laboratório (o Learner Lab não permite criar IAM roles), instala o Docker e
   sobe a imagem `latest` do GHCR na inicialização.
3. **Deploy:** automático a cada merge na `main`. Manualmente, ou para **rollback** a uma versão anterior:
   ```bash
   AWS_PROFILE=academy AWS_REGION=us-east-1 scripts/deploy.sh ghcr.io/by-wagner/devops-na-pratica:<sha>
   ```
   Se a imagem não existir ou o pull falhar, a versão que está no ar é mantida.
