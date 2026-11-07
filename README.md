# DevOps na Prática — Fase 1: Configuração e Automação Inicial

![CI](https://github.com/by-wagner/devops-na-pratica/actions/workflows/ci.yml/badge.svg)

Projeto da disciplina **DevOps na Prática (PUCRS Online)**. Uma API REST simples de lista de tarefas serve de base
para aplicar **Integração Contínua (CI)** com GitHub Actions e **Infraestrutura como Código (IaC)** com Terraform.

## Estrutura

```
.
├── .github/workflows/ci.yml   # pipeline de CI
├── src/                       # código da API (Node.js, sem dependências de produção)
│   ├── app.js                 # rotas e regras
│   └── server.js              # ponto de entrada (lê PORT)
├── test/app.test.js           # testes automatizados (node:test)
└── infra/                     # Terraform (AWS)
    ├── versions.tf            # versão do Terraform e provider AWS
    ├── variables.tf           # parâmetros (região, tipo da instância, CIDRs...)
    ├── network.tf             # VPC, sub-rede, internet gateway, rotas, security group
    ├── compute.tf             # EC2, AMI, IAM role para SSM
    ├── user_data.sh.tftpl     # script de inicialização da EC2
    └── outputs.tf             # IP público e URL da API
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

## Pipeline de CI

Executa em todo `push` e `pull request` para `main` (e manualmente pela aba **Actions**):

1. **app** (matriz Node 22 e 24): checkout → setup Node → `npm ci` → ESLint → Prettier → testes → build → publica o artefato `.tgz`.
2. **infra**: checkout → setup Terraform → `terraform fmt -check` → `terraform init -backend=false` → `terraform validate`.

Se qualquer etapa falhar, o pipeline fica vermelho e o merge na `main` deve ser bloqueado.

## Infraestrutura (Terraform)

Provisiona na AWS: VPC `10.0.0.0/16`, sub-rede pública `10.0.1.0/24`, internet gateway, tabela de rotas,
security group liberando apenas a porta da API, IAM role para acesso via SSM (sem SSH) e uma EC2 `t3.micro`
(Amazon Linux 2023, disco criptografado, IMDSv2) que instala o Node.js e roda a API como serviço systemd.

```bash
cd infra
terraform init
terraform plan  -var="repo_url=https://github.com/by-wagner/devops-na-pratica.git"
terraform apply -var="repo_url=https://github.com/by-wagner/devops-na-pratica.git"
terraform destroy   # remove tudo para não gerar custo
```

> Requer credenciais AWS configuradas (`aws configure` ou variáveis de ambiente). Nesta fase o CI apenas valida os scripts;
> o `apply` é manual.
