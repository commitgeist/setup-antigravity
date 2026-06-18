---
name: git-workflow
description: Git — trunk-based dev, conventional commits, PRs
---

# Git Workflow

Convenções e padrões obrigatórios para fluxo Git.

## Trunk-Based Development

```
main ─────●────●────●────●────●────●──── (sempre deployável)
           \       /      \       /
            feat/PRC-123   fix/PRC-456
            (curta vida)   (curta vida)
```

- `main` é a **única** branch de longa vida
- Feature branches vivem **no máximo 2-3 dias**
- Merge para `main` via PR com **squash merge**
- Deploy automatizado a partir de `main`

## Conventional Commits

### Formato

```
<tipo>(<escopo>): <descrição curta>

[corpo opcional — explica o "porquê"]

[footer opcional — BREAKING CHANGE, refs]
```

### Tipos Permitidos

| Tipo | Quando Usar | Exemplo |
|---|---|---|
| `feat` | Nova funcionalidade | `feat(users): adicionar endpoint de listagem` |
| `fix` | Correção de bug | `fix(auth): corrigir validação de token expirado` |
| `docs` | Documentação | `docs(readme): atualizar instruções de setup` |
| `chore` | Manutenção, deps, CI config | `chore(deps): atualizar zod para v3.23` |
| `refactor` | Refatoração sem mudança de comportamento | `refactor(orders): extrair cálculo de desconto` |
| `test` | Adicionar ou corrigir testes | `test(users): adicionar testes de validação` |
| `ci` | Mudanças em CI/CD | `ci(pipeline): adicionar step de security scan` |
| `perf` | Melhoria de performance | `perf(queries): adicionar índice na tabela users` |
| `style` | Formatação, sem mudança de lógica | `style: aplicar prettier em todo o projeto` |

### Breaking Changes

```
feat(api)!: alterar formato de resposta do endpoint /users

BREAKING CHANGE: campo `fullName` renomeado para `name`.
Clientes da API devem atualizar suas integrações.
```

## SemVer (Versionamento Semântico)

```
v MAJOR . MINOR . PATCH
  │        │       └── fix: correção de bug (compatível)
  │        └────────── feat: nova funcionalidade (compatível)
  └─────────────────── BREAKING CHANGE: mudança incompatível
```

- `fix` → incrementa PATCH: `1.2.3` → `1.2.4`
- `feat` → incrementa MINOR: `1.2.3` → `1.3.0`
- `BREAKING CHANGE` → incrementa MAJOR: `1.2.3` → `2.0.0`

## Branch Naming

```
<tipo>/<TICKET>-<descrição-curta>
```

Exemplos:
- `feat/PRC-123-user-listing`
- `fix/PRC-456-token-validation`
- `chore/PRC-789-update-dependencies`
- `docs/PRC-101-api-documentation`

Regras:
- Sempre em **kebab-case**
- Sempre com **ticket** (rastreabilidade)
- Descrição curta e objetiva (máximo 4-5 palavras)

## PR Checklist

Antes de abrir PR, verificar:

- [ ] Testes passando (`npm test` / `pytest` / `dotnet test` / `go test`)
- [ ] Lint limpo, sem warnings
- [ ] Documentação atualizada (se API pública mudou)
- [ ] PR com **menos de 300 linhas** de diff (dividir se maior)
- [ ] Título do PR segue conventional commits
- [ ] Descrição explica o **porquê**, não apenas o **quê**
- [ ] Sem secrets, tokens, ou credenciais no código
- [ ] Sem `TODO` ou `HACK` sem ticket associado

## Comandos Git Úteis

```bash
# Ver log compacto e bonito
git log --oneline --graph -20

# Rebase interativo para limpar commits antes do PR
git rebase -i HEAD~3

# Stash com nome
git stash push -m "wip: cálculo de desconto"

# Ver diferença staged
git diff --staged

# Desfazer último commit mantendo alterações
git reset --soft HEAD~1

# Buscar branch remota
git fetch origin feat/PRC-123-user-listing
git switch feat/PRC-123-user-listing

# Worktree para trabalhar em duas branches simultaneamente
git worktree add ../projeto-fix fix/PRC-456-token-validation
```

## Anti-Patterns — Evitar Sempre

| Anti-Pattern | Problema | Solução |
|---|---|---|
| Branches de longa vida (+1 semana) | Merge hell, conflitos enormes | Feature flags + merges frequentes |
| Commits `WIP` direto em `main` | Quebra pipeline, bloqueia time | Branch + squash merge |
| `git push --force` em branch compartilhada | Reescreve histórico de outros | Usar `--force-with-lease` se necessário |
| PRs com 1000+ linhas | Impossível revisar com qualidade | Dividir em PRs menores e independentes |
| Commit messages vagas ("fix", "update") | Histórico inútil | Conventional commits descritivos |
| Merge commit do `main` na feature branch | Histórico poluído | Usar `git rebase main` |
| Não linkar ticket no PR | Sem rastreabilidade | Sempre incluir `PRC-XXX` na branch e PR |
