#!/usr/bin/env bats
# Testes do setup-antigravity — rode com: bats tests/

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
  TMP="$(mktemp -d)"
  cd "$TMP"
}

teardown() {
  rm -rf "$TMP"
}

run_setup() {
  run bash "$REPO_DIR/setup.sh" --answers "$REPO_DIR/tests/fixtures/answers.env"
}

@test "setup roda sem erro em modo não-interativo" {
  run_setup
  [ "$status" -eq 0 ]
}

@test "gera settings.json válido (jq empty)" {
  run_setup
  [ -f .gemini/settings.json ]
  run jq empty .gemini/settings.json
  [ "$status" -eq 0 ]
}

@test "settings.json contém selectedModel" {
  run_setup
  run jq -r '.selectedModel' .gemini/settings.json
  [ "$output" = "gemini-2.5-pro" ]
}

@test "agents instalados com modelo substituído (sem placeholder)" {
  run_setup
  [ -f .gemini/agents/architect.md ]
  [ -f .gemini/agents/devops-engineer.md ]
  [ -f .gemini/agents/reviewer.md ]
  grep -q "model: gemini-2.5-pro" .gemini/agents/architect.md
  ! grep -q "{{MODEL}}" .gemini/agents/architect.md
}

@test "skills condicionais pela stack" {
  run_setup
  [ -d .gemini/skills/terraform ]
  [ -d .gemini/skills/kubernetes ]
  [ -d .gemini/skills/azure-pipelines ]
  [ -d .gemini/skills/postgres ]
}

@test "skills universais sempre instaladas" {
  run_setup
  [ -d .gemini/skills/testing ]
  [ -d .gemini/skills/git-workflow ]
}

@test "docs/adr criado com templates" {
  run_setup
  [ -f docs/adr/TEMPLATE.md ]
  [ -f docs/adr/README.md ]
}

@test "GEMINI.md gerado com stack correta" {
  run_setup
  [ -f GEMINI.md ]
  grep -q "devops" GEMINI.md
  grep -q "gemini-2.5-pro" GEMINI.md
}

@test "idempotência: segunda execução preserva backup" {
  run_setup
  [ "$status" -eq 0 ]
  sleep 1
  run_setup
  [ "$status" -eq 0 ]
  ls .gemini/settings.json.bak.* >/dev/null 2>&1 || ls GEMINI.md.bak.* >/dev/null 2>&1
}

@test "--help funciona" {
  run bash "$REPO_DIR/setup.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"setup-antigravity"* ]] || [[ "$output" == *"Uso"* ]]
}
