#!/usr/bin/env bash
# setup-antigravity — Wizard de setup do Antigravity CLI
# Versão: 1.0.0
# Uso:  bash setup.sh [--answers FILE] [-h|--help]
set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"

# ── Requisitos ────────────────────────────────────────────────────────────────
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]] || { [[ "${BASH_VERSINFO[0]}" -eq 4 ]] && [[ "${BASH_VERSINFO[1]}" -lt 3 ]]; }; then
  echo "ERRO: Bash 4.3+ necessário (namerefs). Versão atual: ${BASH_VERSION}" >&2
  [[ "$(uname)" == "Darwin" ]] && echo "Dica: brew install bash" >&2
  exit 1
fi
command -v jq >/dev/null 2>&1 || { echo "ERRO: 'jq' é necessário. Instale com: sudo apt install jq / brew install jq" >&2; exit 1; }
[[ -d "${TEMPLATES_DIR}" ]] || { echo "ERRO: Diretório templates/ não encontrado em ${SCRIPT_DIR}" >&2; exit 1; }

# ── Cores ─────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'
  BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
  RED=''; GREEN=''; CYAN=''; YELLOW=''; BOLD=''; DIM=''; NC=''
fi

# ── Logging ───────────────────────────────────────────────────────────────────
info()  { echo -e "${CYAN}[setup]${NC} $*" >&2; }
ok()    { echo -e "${GREEN}[ok]${NC} $*" >&2; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*" >&2; }
err()   { echo -e "${RED}[err]${NC} $*" >&2; }

# ── Argumentos ────────────────────────────────────────────────────────────────
ANSWERS_FILE=""
NONINTERACTIVE=false

usage() {
  cat >&2 <<EOF
${BOLD}setup-antigravity${NC} v${VERSION}
Wizard de configuração do Antigravity CLI para projetos.

${BOLD}Uso:${NC}
  bash setup.sh                    # Modo interativo (wizard)
  bash setup.sh --answers FILE     # Modo não-interativo
  bash setup.sh -h | --help        # Ajuda

${BOLD}Opções:${NC}
  --answers FILE   Arquivo com respostas pré-definidas (shell-sourceable)
  -h, --help       Mostra esta ajuda
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --answers)
      [[ -z "${2:-}" ]] && { err "Faltou o caminho do arquivo após --answers"; exit 1; }
      ANSWERS_FILE="$2"; NONINTERACTIVE=true; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      err "Opção desconhecida: $1"; usage; exit 1 ;;
  esac
done

if [[ "$NONINTERACTIVE" == true ]]; then
  [[ -f "$ANSWERS_FILE" ]] || { err "Arquivo de respostas não encontrado: $ANSWERS_FILE"; exit 1; }
  # shellcheck disable=SC1090
  source "$ANSWERS_FILE"
fi

# ── Helpers de prompt ─────────────────────────────────────────────────────────
ask() {
  local var="$1" prompt="$2" default="${3:-}"
  if [[ "$NONINTERACTIVE" == true ]]; then
    if [[ -z "${!var:-}" ]]; then declare -g "$var"="$default"; fi
    return
  fi
  local input
  if [[ -n "$default" ]]; then
    read -r -p "$(echo -e "${CYAN}?${NC} ${prompt} [${DIM}${default}${NC}]: ")" input >&2
    declare -g "$var"="${input:-$default}"
  else
    read -r -p "$(echo -e "${CYAN}?${NC} ${prompt}: ")" input >&2
    declare -g "$var"="$input"
  fi
}

pick() {
  local var="$1" prompt="$2" options_csv="$3"
  IFS=',' read -ra options <<< "$options_csv"
  if [[ "$NONINTERACTIVE" == true ]]; then
    if [[ -z "${!var:-}" ]]; then declare -g "$var"="${options[0]}"; fi
    return
  fi
  echo -e "\n${CYAN}?${NC} ${prompt}" >&2
  local i=1
  for opt in "${options[@]}"; do
    echo -e "  ${BOLD}${i})${NC} ${opt}" >&2
    ((i++))
  done
  local choice
  read -r -p "$(echo -e "${CYAN}→${NC} Escolha [1]: ")" choice >&2
  choice="${choice:-1}"
  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
    declare -g "$var"="${options[$((choice-1))]}"
  else
    declare -g "$var"="${options[0]}"
  fi
}

multiselect() {
  local var="$1" prompt="$2" options_csv="$3" out_var="$4"
  local -n __ms_out="$out_var"
  IFS=',' read -ra options <<< "$options_csv"

  if [[ "$NONINTERACTIVE" == true ]]; then
    local val="${!var:-}"
    if [[ -n "$val" ]]; then
      IFS=',' read -ra __ms_out <<< "$val"
    else
      __ms_out=("${options[@]}")
    fi
    return
  fi

  echo -e "\n${CYAN}?${NC} ${prompt} ${DIM}(números separados por vírgula)${NC}" >&2
  local i=1
  for opt in "${options[@]}"; do
    echo -e "  ${BOLD}${i})${NC} ${opt}" >&2
    ((i++))
  done
  local choices
  read -r -p "$(echo -e "${CYAN}→${NC} Escolha [todos]: ")" choices >&2
  if [[ -z "$choices" ]]; then
    __ms_out=("${options[@]}")
  else
    __ms_out=()
    IFS=',' read -ra nums <<< "$choices"
    for n in "${nums[@]}"; do
      n="$(echo "$n" | tr -d ' ')"
      if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#options[@]} )); then
        __ms_out+=("${options[$((n-1))]}")
      fi
    done
  fi
  declare -g "$var"="$(IFS=','; echo "${__ms_out[*]}")"
}

# ── Utilidades ────────────────────────────────────────────────────────────────
has() { local needle="$1"; shift; for item in "$@"; do [[ "$item" == "$needle" ]] && return 0; done; return 1; }

backup_if_exists() {
  local f="$1"
  if [[ -e "$f" ]]; then
    local bak="${f}.bak.$(date +%Y%m%d%H%M%S)"
    cp -a "$f" "$bak"
    warn "Backup: ${f} → ${bak}"
  fi
}

install_template() {
  local src="$1" dest="$2"
  local dest_dir; dest_dir="$(dirname "$dest")"
  mkdir -p "$dest_dir"
  backup_if_exists "$dest"
  cp -a "$src" "$dest"
}

# ═══════════════════════════════════════════════════════════════════════════════
# WIZARD
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}╔══════════════════════════════════════════════╗${NC}" >&2
echo -e "${BOLD}║   🚀 setup-antigravity v${VERSION}              ║${NC}" >&2
echo -e "${BOLD}║   Configuração do Antigravity CLI            ║${NC}" >&2
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}\n" >&2

# ── Step 1: Escopo ────────────────────────────────────────────────────────────
info "Step 1/12 — Escopo"
pick SCOPE "Onde instalar a configuração?" "local,global"

if [[ "$SCOPE" == "local" ]]; then
  TARGET_DIR=".gemini"
  GEMINI_MD="GEMINI.md"
else
  TARGET_DIR="${HOME}/.gemini"
  GEMINI_MD="${TARGET_DIR}/GEMINI.md"
fi

# ── Step 2: Perfil ────────────────────────────────────────────────────────────
info "Step 2/12 — Perfil"
pick PROFILE "Qual o seu perfil de trabalho?" "devops,appdev,tooling,custom"

# ── Step 3: Stack (dinâmico por perfil) ───────────────────────────────────────
info "Step 3/12 — Stack"

declare -a CLOUDS_ARR=() LANGUAGES_ARR=() DBS_ARR=()
CICD="${CICD:-}" IAC="${IAC:-}" USE_K8S="${USE_K8S:-}" FRONTEND="${FRONTEND:-}" BACKEND_FRAMEWORK="${BACKEND_FRAMEWORK:-}" USE_DOCKER="${USE_DOCKER:-}" VCS="${VCS:-}"

case "$PROFILE" in
  devops)
    multiselect CLOUDS "Clouds utilizadas" "AWS,Azure,GCP" CLOUDS_ARR
    pick IAC "Ferramenta de IaC" "Terraform,CloudFormation,Pulumi,Nenhum"
    pick USE_K8S "Usa Kubernetes?" "Sim,Não"
    pick CICD "CI/CD" "GitHub Actions,Azure Pipelines,GitLab CI,Nenhum"
    multiselect DBS "Bancos de dados" "PostgreSQL,MySQL,MongoDB,Redis,Nenhum" DBS_ARR
    ;;
  appdev)
    multiselect LANGUAGES "Linguagens" "TypeScript,Python,C#/.NET,Go,Rust,Java" LANGUAGES_ARR

    # Framework backend condicional
    if has "TypeScript" "${LANGUAGES_ARR[@]:-}"; then
      pick BACKEND_FRAMEWORK "Framework Node.js" "Express,Fastify,NestJS,Hono,Nenhum"
    elif has "Python" "${LANGUAGES_ARR[@]:-}"; then
      pick BACKEND_FRAMEWORK "Framework Python" "FastAPI,Django,Flask,Nenhum"
    elif has "C#/.NET" "${LANGUAGES_ARR[@]:-}"; then
      pick BACKEND_FRAMEWORK "Framework .NET" "Minimal API,ASP.NET MVC,Nenhum"
    elif has "Go" "${LANGUAGES_ARR[@]:-}"; then
      pick BACKEND_FRAMEWORK "Framework Go" "Gin,Echo,Chi,stdlib,Nenhum"
    fi

    pick FRONTEND "Frontend" "React,Next.js,Vue,Angular,Svelte,Nenhum"
    multiselect DBS "Bancos de dados" "PostgreSQL,MySQL,MongoDB,Redis,SQLite,Nenhum" DBS_ARR
    pick USE_DOCKER "Usar Docker?" "Sim,Não"
    pick VCS "Controle de versão" "GitHub,GitLab,Azure DevOps,Bitbucket,Nenhum"
    ;;
  tooling)
    multiselect LANGUAGES "Linguagens" "Python,Go" LANGUAGES_ARR
    multiselect CLOUDS "Cloud APIs" "AWS,Azure,GCP,Nenhum" CLOUDS_ARR
    pick USE_K8S "Interage com Kubernetes?" "Sim,Não"
    pick USE_DOCKER "Usar Docker?" "Sim,Não"
    pick VCS "Controle de versão" "GitHub,GitLab,Azure DevOps,Bitbucket,Nenhum"
    ;;
  custom)
    multiselect CLOUDS "Clouds" "AWS,Azure,GCP,Nenhum" CLOUDS_ARR
    multiselect LANGUAGES "Linguagens" "TypeScript,Python,C#/.NET,Go,Rust,Java" LANGUAGES_ARR
    pick IAC "IaC" "Terraform,CloudFormation,Pulumi,Nenhum"
    pick USE_K8S "Kubernetes?" "Sim,Não"
    pick CICD "CI/CD" "GitHub Actions,Azure Pipelines,GitLab CI,Nenhum"
    pick FRONTEND "Frontend" "React,Next.js,Vue,Angular,Svelte,Nenhum"
    multiselect DBS "Bancos de dados" "PostgreSQL,MySQL,MongoDB,Redis,SQLite,Nenhum" DBS_ARR
    pick USE_DOCKER "Docker?" "Sim,Não"
    pick VCS "VCS" "GitHub,GitLab,Azure DevOps,Bitbucket,Nenhum"
    ;;
esac

# ── Step 4: Autenticação ─────────────────────────────────────────────────────
info "Step 4/12 — Autenticação"
pick AUTH_METHOD "Como autenticar no Antigravity?" "api-key,oauth,vertex-ai,skip"

case "$AUTH_METHOD" in
  api-key)
    ask GEMINI_API_KEY "Cole sua API Key do Google AI Studio" ""
    ;;
  vertex-ai)
    ask GCP_PROJECT "ID do projeto GCP" ""
    ask GCP_LOCATION "Região" "us-central1"
    ;;
  oauth|skip) ;;
esac

# ── Step 5: Modelo ────────────────────────────────────────────────────────────
info "Step 5/12 — Modelo"
pick MODEL "Modelo padrão" "gemini-2.5-pro,gemini-2.5-flash,custom"
if [[ "$MODEL" == "custom" ]]; then
  ask MODEL "ID do modelo customizado" ""
fi

# ── Step 6: Agents ────────────────────────────────────────────────────────────
info "Step 6/12 — Agents"

declare -a AGENTS_ARR=()
case "$PROFILE" in
  devops)
    multiselect AGENTS "Agents a instalar" "architect,devops-engineer,reviewer" AGENTS_ARR
    ;;
  appdev|tooling)
    multiselect AGENTS "Agents a instalar" "architect,developer,reviewer,tester" AGENTS_ARR
    ;;
  custom)
    multiselect AGENTS "Agents a instalar" "architect,developer,devops-engineer,reviewer,tester" AGENTS_ARR
    ;;
esac

# ── Step 7: Instalar Agents ──────────────────────────────────────────────────
info "Step 7/12 — Instalando agents"
AGENTS_DIR="${TARGET_DIR}/agents"
mkdir -p "$AGENTS_DIR"

for agent in "${AGENTS_ARR[@]}"; do
  local_tpl="${TEMPLATES_DIR}/agents/${agent}.md.tpl"
  if [[ -f "$local_tpl" ]]; then
    dest="${AGENTS_DIR}/${agent}.md"
    install_template "$local_tpl" "$dest"
    sed -i "s/{{MODEL}}/${MODEL}/g" "$dest"
    ok "Agent: ${agent} (model: ${MODEL})"
  else
    warn "Template não encontrado: ${agent}.md.tpl"
  fi
done

# ── Step 8: Instalar Skills ──────────────────────────────────────────────────
info "Step 8/12 — Instalando skills"
SKILLS_DIR="${TARGET_DIR}/skills"
mkdir -p "$SKILLS_DIR"
INSTALLED_SKILLS=()

install_skill() {
  local name="$1"
  local src="${TEMPLATES_DIR}/skills/${name}"
  if [[ -d "$src" ]]; then
    local dest="${SKILLS_DIR}/${name}"
    mkdir -p "$dest"
    cp -a "$src/." "$dest/"
    INSTALLED_SKILLS+=("$name")
    ok "Skill: ${name}"
  else
    warn "Skill não encontrada: ${name}"
  fi
}

# Skills condicionais por stack
# Infra
has "AWS"              "${CLOUDS_ARR[@]:-}" && install_skill "aws-infra"
[[ "${IAC:-}" == "Terraform" ]]             && install_skill "terraform"
[[ "${USE_K8S:-}" == "Sim" ]]               && install_skill "kubernetes"
[[ "${CICD:-}" == "Azure Pipelines" ]]      && install_skill "azure-pipelines"
has "PostgreSQL"       "${DBS_ARR[@]:-}"    && install_skill "postgres"

# Dev
has "TypeScript"       "${LANGUAGES_ARR[@]:-}" && install_skill "typescript"
has "Python"           "${LANGUAGES_ARR[@]:-}" && install_skill "python"
has "C#/.NET"          "${LANGUAGES_ARR[@]:-}" && install_skill "dotnet"
has "Go"               "${LANGUAGES_ARR[@]:-}" && install_skill "golang"
[[ "${FRONTEND:-}" == "React" ]]               && install_skill "react"
[[ "${FRONTEND:-}" == "Next.js" ]]             && install_skill "nextjs"

# Docker
[[ "${USE_DOCKER:-}" == "Sim" ]] && install_skill "docker"

# Sempre instaladas
install_skill "testing"
install_skill "git-workflow"

# ── Step 9: Docs/ADR (apenas scope local) ────────────────────────────────────
info "Step 9/12 — Documentação"
if [[ "$SCOPE" == "local" ]]; then
  mkdir -p docs/adr
  install_template "${TEMPLATES_DIR}/docs/adr/TEMPLATE.md" "docs/adr/TEMPLATE.md"
  install_template "${TEMPLATES_DIR}/docs/adr/README.md" "docs/adr/README.md"
  install_template "${TEMPLATES_DIR}/docs/CONCEPTS.md" "docs/CONCEPTS.md"
  ok "docs/adr/ criado com TEMPLATE + README + CONCEPTS"
else
  info "Scope global — docs/adr não instalados"
fi

# ── Step 10: Gerar settings.json ─────────────────────────────────────────────
info "Step 10/12 — Gerando settings.json"
CONFIG_FILE="${TARGET_DIR}/settings.json"
backup_if_exists "$CONFIG_FILE"

cfg='{"$schema":"https://raw.githubusercontent.com/google-gemini/gemini-cli/main/schemas/settings.schema.json"}'

# MCPs condicionais
cfg="$(jq '. + {mcpServers: {}}' <<< "$cfg")"

# GitHub MCP
if [[ "${VCS:-}" == "GitHub" ]]; then
  cfg="$(jq '.mcpServers.github = {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-github"],
    "env": {"GITHUB_TOKEN": "$GITHUB_TOKEN"}
  }' <<< "$cfg")"
fi

# Kubernetes MCP
if [[ "${USE_K8S:-}" == "Sim" ]]; then
  cfg="$(jq '.mcpServers.kubernetes = {
    "command": "npx",
    "args": ["-y", "kubernetes-mcp-server@latest"],
    "disabled": true
  }' <<< "$cfg")"
fi

# Context7 (sempre)
cfg="$(jq '.mcpServers.context7 = {
  "command": "npx",
  "args": ["-y", "@upstash/context7-mcp@latest"]
}' <<< "$cfg")"

# Auth no settings.json
case "${AUTH_METHOD:-skip}" in
  api-key)
    if [[ -n "${GEMINI_API_KEY:-}" ]]; then
      # Salvar no .env ao invés de settings.json (segurança)
      local_env="${TARGET_DIR}/.env"
      backup_if_exists "$local_env"
      echo "GEMINI_API_KEY=${GEMINI_API_KEY}" > "$local_env"
      ok "API Key salva em ${local_env}"
    fi
    ;;
  vertex-ai)
    local_env="${TARGET_DIR}/.env"
    backup_if_exists "$local_env"
    cat > "$local_env" <<ENVEOF
GOOGLE_CLOUD_PROJECT=${GCP_PROJECT:-}
GOOGLE_CLOUD_LOCATION=${GCP_LOCATION:-us-central1}
GOOGLE_GENAI_USE_VERTEXAI=True
ENVEOF
    ok "Vertex AI config salva em ${local_env}"
    ;;
esac

# Modelo no settings
if [[ -n "${MODEL:-}" ]]; then
  cfg="$(jq --arg m "$MODEL" '. + {selectedModel: $m}' <<< "$cfg")"
fi

mkdir -p "$TARGET_DIR"
echo "$cfg" | jq '.' > "$CONFIG_FILE"

# Validar JSON
if jq empty "$CONFIG_FILE" 2>/dev/null; then
  ok "settings.json gerado e validado"
else
  err "settings.json com JSON inválido!"; exit 1
fi

# ── Step 11: Gerar GEMINI.md ─────────────────────────────────────────────────
info "Step 11/12 — Gerando GEMINI.md"
backup_if_exists "$GEMINI_MD"

{
  echo "# Configuração do Projeto — Antigravity CLI"
  echo ""
  echo "> Gerado por setup-antigravity v${VERSION} em $(date -Iseconds)"
  echo ""

  # Agents
  echo "## Agents Disponíveis"
  echo ""
  for agent in "${AGENTS_ARR[@]}"; do
    case "$agent" in
      architect)        echo "- **@architect** — Planeja e projeta soluções. Nunca implementa diretamente." ;;
      developer)        echo "- **@developer** — Implementa features, APIs e serviços." ;;
      devops-engineer)  echo "- **@devops-engineer** — Gerencia infra, CI/CD e deploys." ;;
      reviewer)         echo "- **@reviewer** — Revisa código (read-only). Roda linters e testes." ;;
      tester)           echo "- **@tester** — Escreve apenas arquivos de teste." ;;
    esac
  done
  echo ""

  # Stack
  echo "## Stack"
  echo ""
  echo "- **Perfil**: ${PROFILE}"
  [[ -n "${CLOUDS:-}" ]]             && echo "- **Clouds**: ${CLOUDS}"
  [[ -n "${LANGUAGES:-}" ]]          && echo "- **Linguagens**: ${LANGUAGES}"
  [[ -n "${BACKEND_FRAMEWORK:-}" ]]  && echo "- **Framework**: ${BACKEND_FRAMEWORK}"
  [[ -n "${FRONTEND:-}" ]]           && echo "- **Frontend**: ${FRONTEND}"
  [[ -n "${IAC:-}" && "${IAC}" != "Nenhum" ]]     && echo "- **IaC**: ${IAC}"
  [[ -n "${USE_K8S:-}" ]]            && echo "- **Kubernetes**: ${USE_K8S}"
  [[ -n "${CICD:-}" && "${CICD}" != "Nenhum" ]]   && echo "- **CI/CD**: ${CICD}"
  [[ -n "${DBS:-}" ]]                && echo "- **Bancos**: ${DBS}"
  [[ -n "${USE_DOCKER:-}" ]]         && echo "- **Docker**: ${USE_DOCKER}"
  [[ -n "${VCS:-}" && "${VCS}" != "Nenhum" ]]     && echo "- **VCS**: ${VCS}"
  echo ""

  # Skills
  echo "## Skills Instaladas"
  echo ""
  for skill in "${INSTALLED_SKILLS[@]}"; do
    echo "- \`${skill}\`"
  done
  echo ""

  # Modelo
  echo "## Modelo"
  echo ""
  echo "- **Modelo padrão**: \`${MODEL}\`"
  echo ""

  # Regras
  echo "## Regras do Projeto"
  echo ""
  echo "1. **Código = Teste** — Toda feature deve ter testes correspondentes"
  echo "2. **Valide antes de commitar** — Rode linters/testes antes de abrir PR"
  echo "3. **Secrets** — NUNCA hardcode. Use variáveis de ambiente ou secret managers"
  echo "4. **Conventional Commits** — feat:, fix:, docs:, chore:, refactor:, test:, ci:"
  echo "5. **PRs pequenos** — Máximo ~300 linhas. Mudanças grandes passam pelo architect primeiro"
  echo "6. **Não afirme estado sem verificar** — Sempre confirme com ferramentas antes de afirmar"
  echo "7. **Não invente flags/opções de CLI** — Consulte --help ou documentação"
  echo ""

  # Workflow
  echo "## Workflow Recomendado"
  echo ""
  echo "1. **Mudança complexa**: architect → ADR → aprovação → developer → reviewer → PR"
  echo "2. **Mudança simples**: developer (com plano) → reviewer → PR"
  echo "3. **Debug**: developer investiga → propõe fix → tester valida → PR"
  echo ""

} > "$GEMINI_MD"

ok "GEMINI.md gerado"

# ── Step 12: Resumo ──────────────────────────────────────────────────────────
info "Step 12/12 — Resumo"

# Soft dependency check
echo "" >&2
MISSING_DEPS=()
command -v npx  >/dev/null 2>&1 || MISSING_DEPS+=("npx (Node.js)")
command -v docker >/dev/null 2>&1 || MISSING_DEPS+=("docker")

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
  warn "Dependências opcionais não encontradas:"
  for dep in "${MISSING_DEPS[@]}"; do
    echo -e "  ${YELLOW}•${NC} ${dep}" >&2
  done
  echo "" >&2
fi

echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}" >&2
echo -e "${BOLD}║   ✅ Setup concluído com sucesso!            ║${NC}" >&2
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}" >&2
echo "" >&2
echo -e "  ${BOLD}Escopo:${NC}     ${SCOPE}" >&2
echo -e "  ${BOLD}Perfil:${NC}     ${PROFILE}" >&2
echo -e "  ${BOLD}Modelo:${NC}     ${MODEL}" >&2
echo -e "  ${BOLD}Agents:${NC}     ${AGENTS}" >&2
echo -e "  ${BOLD}Skills:${NC}     $(IFS=','; echo "${INSTALLED_SKILLS[*]}")" >&2
echo -e "  ${BOLD}Config:${NC}     ${CONFIG_FILE}" >&2
echo -e "  ${BOLD}Instruções:${NC} ${GEMINI_MD}" >&2
echo "" >&2
echo -e "  ${CYAN}Próximo passo:${NC} Execute ${BOLD}antigravity${NC} no diretório do projeto." >&2
echo "" >&2
