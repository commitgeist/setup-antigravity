# setup-antigravity

> **Ferramenta**: [Gemini CLI (Antigravity)](https://github.com/google-gemini/gemini-cli) — terminal de IA agêntico do Google.

Setup padronizado do Gemini CLI para times de DevOps, Dev e Tooling.
Um comando instala: agentes com guardrails, skills com templates,
settings.json com MCPs e GEMINI.md — tudo adaptado à sua stack.

## Qual setup usar?

| Aspecto | setup-opencode | setup-opencode-dev | setup-opencode-devtools | **setup-antigravity** | setup-copilot |
|---|---|---|---|---|---|
| **Motor** | OpenCode | OpenCode | OpenCode | **Gemini CLI** | GitHub Copilot CLI |
| **Persona** | DevOps/SRE | Dev apps | Dev ferramentas | **Multi-perfil** | Dev geral |
| **Config gerada** | opencode.json | opencode.json | opencode.json | **settings.json + GEMINI.md** | copilot-instructions.md |
| **Perfis** | fixo (DevOps) | fixo (Dev) | fixo (Tooling) | **devops, appdev, tooling, custom** | N/A |

---

## O que é o Gemini CLI (Antigravity)?

O [Gemini CLI](https://github.com/google-gemini/gemini-cli) é um terminal de IA
agêntico do Google — um TUI que conecta modelos Gemini a ferramentas reais (bash,
leitura/escrita de arquivos, APIs) através de **agentes** com papéis definidos.

Conceitos-chave:

| Conceito | O que é | Exemplo |
|---|---|---|
| **Agent** | Um "profissional" com modelo, permissões e instruções | `architect` planeja, `devops-engineer` executa |
| **Skill** | Pacote de instruções para uma área específica | `terraform`, `kubernetes`, `typescript` |
| **MCP** | Conexão com API externa (GitHub, K8s, etc.) | O agente consulta e opera recursos reais |
| **GEMINI.md** | Arquivo de instruções do projeto (como AGENTS.md) | Define regras, stack e workflow |
| **settings.json** | Config do Gemini CLI: modelo, MCPs, preferências | Vive em `.gemini/settings.json` |

> Este repo **não é o Gemini CLI** — é um setup que configura o Gemini CLI
> com agentes seguros, skills contextuais e workflow baseado em ADR.

---

## Comece por aqui

### 0. Pré-requisitos

```bash
# 1. Instalar o Gemini CLI
npm install -g @google/gemini-cli
# ou: npx @google/gemini-cli

# 2. Dependências do setup
jq --version    # apt install jq / brew install jq
bash --version  # precisa 4.3+ (macOS: brew install bash)
node --version  # 20+ (para MCPs npm-based)

# 3. Autenticação (escolha um)
#    - API Key: https://aistudio.google.com/apikey
#    - OAuth: antigravity login
#    - Vertex AI: gcloud auth application-default login
```

### 1. Instalar o setup

```bash
git clone https://github.com/commitgeist/setup-antigravity.git
cd setup-antigravity
./setup.sh
```

O wizard de 12 passos pergunta seu perfil, stack, autenticação, modelo e
agentes — gera tudo personalizado. Em ~2 minutos você tem agentes, skills,
settings.json e GEMINI.md prontos.

> Modo não-interativo (padronizar time / CI):
> `cp answers.env.example answers.env && vi answers.env && ./setup.sh --answers answers.env`

### 2. Entender o fluxo

O coração do setup é o **ADR** (Architecture Decision Record) — um documento
que registra **o quê** vai ser feito, **por quê**, quais alternativas foram
descartadas e **como** implementar passo a passo.

> Sem ADR → agente improvisa e erra. Com ADR → agente segue plano auditável.

```
┌───────────────┐     ┌──────────┐     ┌──────────────────┐     ┌──────────┐
│   architect   │────▶│  HUMANO  │────▶│ devops-engineer  │────▶│ @reviewer│
│ planeja e gera│     │ revisa e │     │ implementa passo │     │ valida   │
│ o ADR         │     │ aprova   │     │ a passo          │     │ contra   │
└───────────────┘     └──────────┘     └──────────────────┘     │ o ADR    │
└──────────┘
```

1. **architect** gera `docs/adr/0001-titulo.md` com plano completo
2. **Você** revisa e aprova (gate humano obrigatório)
3. **devops-engineer** (ou **developer**) lê o ADR e executa passo a passo
4. **@reviewer** compara implementação vs ADR e aponta desvios
5. **Você** abre o PR

#### Agentes disponíveis por perfil

O wizard instala agentes diferentes conforme o perfil escolhido:

| Perfil | Agentes disponíveis |
|---|---|
| **devops** | architect, devops-engineer, reviewer |
| **appdev** | architect, developer, reviewer, tester |
| **tooling** | architect, developer, reviewer, tester |
| **custom** | architect, developer, devops-engineer, reviewer, tester |

#### Os agentes em detalhe

```
       ┌─────────────────────────────────────────────────────────┐
       │                    architect                            │
       │  ORQUESTRADOR — planeja, gera ADR                      │
       │  bash: deny │ write: só docs/adr/ e docs/design/       │
       │  Nunca implementa. Nunca executa comando.              │
       └────────────────────────┬────────────────────────────────┘
                                │ gera ADR
                                ▼
       ┌─────────────────────────────────────────────────────────┐
       │                     HUMANO                              │
       │  Gate obrigatório — lê, questiona, aprova ou rejeita   │
       └────────────────────────┬────────────────────────────────┘
                                │ ADR aprovado
                                ▼
       ┌─────────────────────────────────────────────────────────┐
       │           devops-engineer / developer                   │
       │  OPERADOR EXECUTOR — implementa conforme o ADR         │
       │  bash: allow │ write: tudo                             │
       │  apply/destroy = pede confirmação / bloqueado          │
       └────────────────────────┬────────────────────────────────┘
                                │ implementou
                                ▼
       ┌─────────────────────────────────────────────────────────┐
       │                    @reviewer                            │
       │  VALIDADOR — compara código vs ADR                     │
       │  bash: read-only │ write: bloqueado                    │
       │  Só pode: lint, test, diff, validate                   │
       └─────────────────────────────────────────────────────────┘
```

| Agente | Papel | Escrever arquivos | Executar bash | Destruir recursos |
|---|---|---|---|---|
| `architect` | Orquestrador | Só `docs/adr/*`, `docs/design/*` | ❌ Bloqueado | ❌ |
| `devops-engineer` | Executor (infra) | ✅ Tudo | ✅ (apply=ask) | ❌ deny |
| `developer` | Executor (código) | ✅ Tudo | ✅ | ❌ deny |
| `reviewer` | Validador | ❌ Bloqueado | 🔍 Só leitura | ❌ |
| `tester` | Testador | Só arquivos de teste | ✅ (testes) | ❌ |

### 3. Estrutura gerada

O setup gera arquivos dentro do seu repositório de projeto:

```
setup-antigravity/setup.sh  ──▶  seu-repo/
                                  ├── .gemini/
                                  │   ├── settings.json      (config: modelo, MCPs)
                                  │   ├── agents/            (agentes com guardrails)
                                  │   └── skills/            (terraform, k8s, etc)
                                  ├── GEMINI.md              (instruções do projeto)
                                  └── docs/adr/              (seus ADRs vão aqui)
```

### 4. Como usar na vida real

> **Importante:** o setup-antigravity é um **instalador**, não o repo onde você trabalha.
> Você roda o setup dentro do repo do seu projeto e depois trabalha
> no seu repo normalmente com `antigravity`.

#### Exemplo completo: subir um cluster ECS com Terraform (perfil devops)

```bash
# ── 1. Criar o repo do projeto ──
mkdir infra-ecs && cd infra-ecs
git init

# ── 2. Rodar o setup (uma vez só) ──
#    Pode clonar ou apontar direto pro script
git clone https://github.com/commitgeist/setup-antigravity.git /tmp/setup-antigravity
/tmp/setup-antigravity/setup.sh
#
#   Wizard pergunta:
#     Perfil? → devops
#     Cloud?  → AWS
#     IaC?    → Terraform
#     K8s?    → Não
#     CI/CD?  → Azure Pipelines (ou GitHub Actions)
#     Banco?  → Nenhum
#     Auth?   → api-key
#     Modelo? → gemini-2.5-pro
#     Agents? → architect, devops-engineer, reviewer
#
#   Resultado: .gemini/ (settings.json, agents/, skills/),
#   GEMINI.md, docs/adr/

# ── 3. Abrir o Gemini CLI ──
antigravity
```

**No architect** — pedir o plano:

```
> Planeje a criação de um cluster ECS Fargate na AWS para a aplicação
> "api-pagamentos" (.NET 8, porta 8080). Preciso de:
> - VPC com subnets públicas e privadas
> - ALB com HTTPS (certificado ACM)
> - ECS Cluster Fargate com service e task definition
> - ECR para as imagens
> - CloudWatch logs
> - Autoscaling baseado em CPU (min 2, max 10)
> Região us-east-1, tudo via Terraform.
```

O architect gera `docs/adr/0001-criar-ecs-fargate-api-pagamentos.md` com:
- Contexto e motivação
- Decisão (Fargate vs EC2, por quê)
- Alternativas descartadas
- Estimativa de custo
- **Implementation Guidelines** com passo a passo numerado

**Você revisa o ADR** — lê, ajusta se necessário, aprova.

**Trocar para devops-engineer** — mandar implementar:

```
> @devops-engineer Implemente docs/adr/0001-criar-ecs-fargate-api-pagamentos.md
> Um passo por vez. Mostre o plan antes de qualquer apply.
```

O engineer:
1. Cria os módulos `.tf` (VPC, ALB, ECS, ECR, IAM)
2. Roda `terraform fmt` + `terraform validate` + `tflint` + `checkov`
3. Executa `terraform plan` e mostra o resultado
4. Pede confirmação antes do `apply`
5. Valida que o serviço está healthy

**@reviewer** — validar:

```
> @reviewer valide a implementação contra docs/adr/0001-criar-ecs-fargate-api-pagamentos.md
```

O reviewer compara o código gerado vs o ADR e aponta desvios
(porta errada, faltou autoscaling, security group aberto demais, etc).

**Você abre o PR** — com ADR, código e validação documentados.

#### Exemplo completo: criar API FastAPI com PostgreSQL (perfil appdev)

```bash
# ── 1. Criar o repo do projeto ──
mkdir api-clientes && cd api-clientes
git init

# ── 2. Rodar o setup (uma vez só) ──
/tmp/setup-antigravity/setup.sh
#
#   Wizard pergunta:
#     Perfil?     → appdev
#     Linguagens? → Python
#     Framework?  → FastAPI
#     Frontend?   → Nenhum
#     Banco?      → PostgreSQL
#     Docker?     → Sim
#     VCS?        → GitHub
#     Auth?       → api-key
#     Modelo?     → gemini-2.5-pro
#     Agents?     → architect, developer, reviewer, tester
#
#   Resultado: .gemini/ (settings.json, agents/, skills/),
#   GEMINI.md, docs/adr/

# ── 3. Abrir o Gemini CLI ──
antigravity
```

**No architect** — pedir o plano:

```
> Planeje uma API REST para gestão de clientes com:
> - CRUD completo (nome, email, telefone, endereço)
> - Autenticação JWT
> - PostgreSQL com Alembic migrations
> - Docker Compose para dev local
> - Testes com pytest (mínimo 80% cobertura)
> Gere o ADR.
```

O architect gera `docs/adr/0001-api-clientes-fastapi.md` com:
- Estrutura de diretórios proposta
- Modelos de dados (schemas Pydantic)
- Rotas e endpoints
- Estratégia de testes
- Passo a passo de implementação

**Você revisa o ADR** — lê, ajusta se necessário, aprova.

**Trocar para developer** — mandar implementar:

```
> @developer Implemente docs/adr/0001-api-clientes-fastapi.md
> Um passo por vez. Comece pela estrutura e modelos.
```

O developer:
1. Cria a estrutura de diretórios (`src/`, `tests/`, `alembic/`)
2. Define os modelos SQLAlchemy e schemas Pydantic
3. Implementa os endpoints CRUD
4. Configura Alembic migrations
5. Cria o `docker-compose.yml` (app + PostgreSQL)
6. Roda `ruff check` + `mypy` + `pytest`

**@tester** — escrever testes:

```
> @tester escreva testes para os endpoints CRUD de clientes.
> Cubra: happy path, validação, not found, duplicata de email.
```

**@reviewer** — validar:

```
> @reviewer valide a implementação contra docs/adr/0001-api-clientes-fastapi.md
```

#### Exemplo DevOps: VPC com módulos Terraform reutilizáveis

```bash
mkdir infra-networking && cd infra-networking
git init
/tmp/setup-antigravity/setup.sh
#   Perfil? → devops | Cloud? → AWS | IaC? → Terraform | K8s? → Sim
```

```
> Planeje a criação de uma VPC com subnets públicas e privadas,
> NAT Gateway, Security Groups e VPC Flow Logs.
> Região us-east-1, tudo via Terraform com módulos reutilizáveis.
> O módulo de VPC deve ser parametrizável para reusar em dev/qa/prod.
```

#### Exemplo Tooling: CLI em Go para gerenciar deploys

```bash
mkdir deploy-cli && cd deploy-cli
git init
/tmp/setup-antigravity/setup.sh
#   Perfil? → tooling | Linguagens? → Go | Cloud? → AWS | K8s? → Sim
```

```
> Planeje uma CLI em Go chamada "dctl" para gerenciar deploys no ECS.
> Subcomandos: dctl deploy, dctl rollback, dctl status, dctl logs.
> Usar cobra para CLI, AWS SDK v2, e table output com bubbletea.
```

#### Resumo visual

```
setup-antigravity/setup.sh  ──▶  seu-repo/
                                  ├── .gemini/
                                  │   ├── settings.json      (config: modelo, MCPs)
                                  │   ├── agents/            (agentes com guardrails)
                                  │   └── skills/            (terraform, k8s, etc)
                                  ├── GEMINI.md              (instruções do projeto)
                                  ├── docs/adr/              (seus ADRs vão aqui)
                                  └── ... seu código Terraform, Python, Go, etc
```

O setup configura. O Gemini CLI executa. Os agentes seguem os ADRs.
Depois de rodar o setup, você **esquece ele** e trabalha no seu repo.

### 5. Usar o Gemini CLI pra aprender

O próprio Gemini CLI lê os arquivos do repo. Então depois de rodar o setup
dentro deste repo, você pode pedir pra ele te ensinar usando o material
que já está aqui:

```bash
cd setup-antigravity
antigravity
```

#### Aprender sobre os agentes

```
> Leia os agentes em .gemini/agents/ e me explique as permissões de cada
> um. O que o architect pode fazer que o developer não pode? E vice-versa?
```

```
> Com base no architect.md, me explique por que ele não pode executar bash
> e por que isso é uma decisão de segurança importante
```

#### Entender o que o setup gerou

```
> Leia o .gemini/settings.json e me explique cada MCP configurado:
> o que ele faz, quando usar e quando NÃO usar
```

```
> Leia o GEMINI.md e me diga quais regras estão definidas pro projeto.
> Quais dessas regras são invioláveis e por quê?
```

#### Aprender a criar coisas novas

```
> Com base em templates/agents/architect.md.tpl, me ensine como criar um
> agente novo "secops" que só pode ler e nunca pode executar bash
```

```
> Me guie passo a passo pra criar uma skill nova chamada "helm-deploy"
> que padronize deploy via Helm charts
```

#### Simular cenários

```
> Simule que sou novo no time. Me faça um onboarding de 15 minutos:
> o que eu preciso saber pra começar a operar sem quebrar nada?
```

```
> Finja que um pod está em CrashLoopBackOff. Me guie pelo processo de
> diagnóstico — quais comandos o devops-engineer rodaria?
```

> **Dica:** quanto mais específico o prompt, melhor o resultado. Em vez de
> "me ensina sobre skills", peça "leia o arquivo X e me explique Y como se
> eu fosse Z".

### 6. Comandos úteis no dia a dia

Dentro do Gemini CLI, esses prompts cobrem 80% do trabalho real:

#### Planejamento

```
> Planeje a criação de <recurso>. Considere custo, segurança e rollback.
> Gere o ADR em docs/adr/

> Preciso migrar <serviço> de <origem> para <destino>. Analise riscos,
> estime custo e proponha um ADR com implementation guidelines.
```

#### Implementação

```
> @devops-engineer Implemente docs/adr/0001-titulo.md, um passo por vez.
> Mostre o plan antes de qualquer apply e espere minha confirmação.

> Roda terraform fmt, validate, tflint e checkov neste módulo.
> Só me mostra se tiver erro.

> Crie o Dockerfile pra esta app .NET 8 seguindo CIS Benchmark.
> Multi-stage, non-root, healthcheck, pin de versão.
```

#### Validação e review

```
> @reviewer valide a implementação contra docs/adr/0001-titulo.md

> Audite todos os Dockerfiles do repo. Pra cada um, liste violações
> de segurança. Não modifique — só relatório.
```

#### Troubleshooting

```
> Os pods do deployment X estão em CrashLoopBackOff. Diagnostique:
> verifique logs, events, describe e me dê a causa raiz.

> O terraform plan está mostrando destroy de um recurso que não deveria.
> Analise o state e me explique o que está causando.
```

#### Desenvolvimento

```
> @developer Crie um endpoint POST /api/v1/orders que valide o payload
> com Pydantic, salve no PostgreSQL e retorne 201. Inclua testes.

> @tester Escreva testes de integração para o módulo de autenticação.
> Cubra: login válido, senha errada, token expirado, rate limiting.

> Refatore src/services/payment.py — está com 400 linhas. Extraia
> as responsabilidades em classes menores seguindo SRP.
```

### 7. Modelos recomendados

#### Se você paga (melhor qualidade)

| Agente | Modelo | Por quê |
|---|---|---|
| architect | `gemini-2.5-pro` | Melhor em planejamento e raciocínio longo |
| devops-engineer / developer | `gemini-2.5-pro` | Bom em código e IaC |
| reviewer / tester | `gemini-2.5-flash` | Rápido e barato, suficiente pra validação |

#### Se você quer econômico

| Agente | Modelo | Por quê |
|---|---|---|
| architect | `gemini-2.5-pro` | Vale o custo extra pra planejamento |
| devops-engineer / developer | `gemini-2.5-flash` | Rápido, bom custo-benefício |
| reviewer / tester | `gemini-2.5-flash` | Tarefas mais simples |

#### Via Vertex AI (enterprise)

Se você usa Google Cloud, autentique via Vertex AI para ter:
- SLA enterprise e compliance
- Modelos fine-tuned disponíveis
- Billing integrado ao projeto GCP

```bash
# No setup, escolher: Auth? → vertex-ai
# Variáveis necessárias:
export GOOGLE_CLOUD_PROJECT=meu-projeto
export GOOGLE_CLOUD_LOCATION=us-central1
export GOOGLE_GENAI_USE_VERTEXAI=True
```

### 8. Diferença para o setup-opencode

| Aspecto | setup-opencode | setup-antigravity |
|---|---|---|
| Motor | OpenCode CLI | Gemini CLI |
| Config principal | `opencode.json` | `.gemini/settings.json` |
| Instruções | `AGENTS.md` | `GEMINI.md` |
| Modelos | Multi-provider (Anthropic, OpenAI, Ollama, Zen) | Gemini (Google AI Studio / Vertex AI) |
| Perfis | Fixo (DevOps/SRE) | Dinâmico (devops, appdev, tooling, custom) |
| Autenticação | API Key por provider | API Key / OAuth / Vertex AI |
| Skills | Mesma biblioteca | Mesma biblioteca |
| Agentes | Mesmos templates | Mesmos templates |

---

## Referência rápida

### Como funciona a configuração

As configurações são carregadas em camadas:

```
~/.gemini/settings.json   ← GLOBAL (todo repo)
~/.gemini/GEMINI.md       ← GLOBAL (todo repo)
  + .gemini/settings.json ← LOCAL (só este repo)
  + GEMINI.md             ← LOCAL (só este repo, sobrescreve o global)
```

**Agentes e MCPs definidos no global** ficam disponíveis em QUALQUER repo.
**Agentes e MCPs definidos no local** valem só pra aquele repo.

> O local sempre sobrescreve o global nos mesmos campos.

### Chamando agentes

No chat, use `@nome-do-agente`:

```
@devops-engineer "implemente o ADR 0001"
@reviewer "valide contra docs/adr/0001-*.md"
@developer "crie os testes unitários para o módulo auth"
@tester "rode a suite completa e me dê o relatório"
```

### Exemplos de agentes por área

#### ☁️ Infra / DevOps

| Agente | Descrição |
|---|---|
| `@devops-engineer` | Opera infra: Terraform, K8s, pipelines, networking |
| `@architect` | Planeja mudanças e gera ADRs — nunca implementa |
| `@reviewer` | Valida implementação contra padrões e ADRs (read-only) |

#### 💻 Desenvolvimento

| Agente | Descrição |
|---|---|
| `@developer` | Implementa features, APIs, serviços |
| `@tester` | Escreve testes (unit, integration, e2e) |
| `@architect` | Planeja arquitetura e define padrões |
| `@reviewer` | Code review automatizado |

### Fluxo completo (ADR → Implementação → Review)

```
1. architect:              "Planeje <mudança>"             → gera docs/adr/NNNN-titulo.md
2. HUMANO:                 revisa e aprova o ADR            (gate obrigatório)
3. devops-engineer / dev:  "Implemente docs/adr/NNNN-*"    → executa passo a passo
4. @reviewer:              "Valide contra o ADR"            → aponta desvios
5. HUMANO:                 abre PR
```

### Dicas rápidas

- **Skills** carregam contexto sob demanda — são o manual do agente
- **Secrets**: nunca hardcode — use variáveis de ambiente ou secret managers
- **Pin versões**: `~> X.Y` em providers, SHA em imagens Docker, nunca `:latest`
- **Validação sempre**: `terraform plan`, `kubectl diff`, `tflint`, `checkov`
- **Modelo errado?** Edite o `model:` no frontmatter de `.gemini/agents/*.md`
- **Prompts curtos** funcionam melhor — um passo por vez, siga os checkpoints das skills

---

## Variáveis do answers.env

```bash
# Rodar o setup interativo
./setup.sh

# Rodar com respostas pré-definidas (CI / padronização)
./setup.sh --answers answers.env

# Ajuda
./setup.sh --help
```

| Variável | Valores | Descrição |
|---|---|---|
| `SCOPE` | `local`, `global` | Onde instalar a config |
| `PROFILE` | `devops`, `appdev`, `tooling`, `custom` | Perfil de trabalho |
| `CLOUDS` | `AWS,Azure,GCP` | Clouds utilizadas |
| `LANGUAGES` | `TypeScript,Python,C#/.NET,Go,Rust,Java` | Linguagens |
| `IAC` | `Terraform`, `CloudFormation`, `Pulumi`, `Nenhum` | Ferramenta de IaC |
| `USE_K8S` | `Sim`, `Não` | Usa Kubernetes |
| `CICD` | `GitHub Actions`, `Azure Pipelines`, `GitLab CI` | CI/CD |
| `DBS` | `PostgreSQL,MySQL,MongoDB,Redis,SQLite` | Bancos de dados |
| `FRONTEND` | `React`, `Next.js`, `Vue`, `Angular`, `Svelte` | Frontend |
| `USE_DOCKER` | `Sim`, `Não` | Usar Docker |
| `VCS` | `GitHub`, `GitLab`, `Azure DevOps`, `Bitbucket` | Controle de versão |
| `AUTH_METHOD` | `api-key`, `oauth`, `vertex-ai`, `skip` | Autenticação |
| `MODEL` | `gemini-2.5-pro`, `gemini-2.5-flash`, `custom` | Modelo padrão |
| `AGENTS` | `architect,developer,devops-engineer,reviewer,tester` | Agentes a instalar |
