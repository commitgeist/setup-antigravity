---
name: terraform
description: Terraform IaC — modules, state, providers, validation
---

# Terraform — Infraestrutura como Código

## Estrutura de Módulos

Organize cada módulo com a seguinte estrutura:

```
modules/<nome-modulo>/
├── main.tf          # Recursos principais
├── variables.tf     # Variáveis de entrada
├── outputs.tf       # Valores de saída
├── versions.tf      # Constraints de provider e terraform
├── locals.tf        # Valores computados localmente
└── data.tf          # Data sources
```

- Módulos reutilizáveis ficam em `modules/`
- Ambientes (dev/qa/prod) ficam em `environments/<env>/` e consomem os módulos
- Cada environment tem seu próprio `backend.tf` com state remoto isolado

## State Remoto

- **Sempre** use backend remoto (S3 + DynamoDB para lock, ou Azure Storage)
- Nunca commite `*.tfstate` ou `*.tfstate.backup`
- Um state por ambiente — **nunca** compartilhe state entre envs
- Para manipulação de state: `terraform state mv` e `terraform state rm` com extremo cuidado
- Antes de qualquer `state rm`, faça backup: `terraform state pull > backup.tfstate`

## Pinning de Providers

```hcl
terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"   # CORRETO: ~> permite patch updates
      # version = ">= 3.90" # ERRADO: permite major breaking changes
    }
  }
}
```

**Regra**: sempre `~> X.Y`, nunca `>= X.Y`.

## Naming de Recursos

Siga a convenção do projeto: `prc` + `env` + `sistema` + `region` + `tipo` + `seq3dig`

```hcl
locals {
  prefix = "prc${var.env}${var.system_id}${var.region_code}"
  name   = "${local.prefix}${var.resource_type}${format("%03d", var.sequence)}"
}
```

## Padrões de Variáveis e Outputs

```hcl
variable "env" {
  description = "Ambiente: p (prod), i (qa), d (dev)"
  type        = string
  validation {
    condition     = contains(["p", "i", "d"], var.env)
    error_message = "Ambiente deve ser p, i ou d."
  }
}

output "resource_id" {
  description = "ID do recurso criado"
  value       = azurerm_resource.main.id
  sensitive   = false
}
```

- Sempre adicione `description` em variáveis e outputs
- Use `validation` blocks para inputs críticos
- Marque outputs com dados sensíveis como `sensitive = true`

## Lifecycle Rules

```hcl
resource "azurerm_storage_account" "main" {
  # ...
  lifecycle {
    prevent_destroy = true  # Protege contra deleção acidental
    ignore_changes  = [tags["updated_at"]]
  }
}
```

- `prevent_destroy` em recursos críticos (databases, storage, key vaults)
- `ignore_changes` para campos gerenciados externamente

## Import de Recursos Existentes

```hcl
# Terraform 1.5+: import block declarativo
import {
  to = azurerm_resource_group.existing
  id = "/subscriptions/.../resourceGroups/my-rg"
}

# Workflow:
# 1. Escreva o resource block
# 2. Adicione o import block
# 3. terraform plan — verifique que não há changes
# 4. Remova o import block após sucesso
```

## Workflow de Validação (executar ANTES de qualquer apply)

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Formatação ==="
terraform fmt -recursive -check -diff

echo "=== Validação de Sintaxe ==="
terraform init -backend=false
terraform validate

echo "=== Linting ==="
tflint --recursive

echo "=== Segurança ==="
checkov -d . --quiet --compact

echo "=== Plan ==="
terraform plan -out=tfplan -detailed-exitcode
# Exit code 0 = sem mudanças, 1 = erro, 2 = mudanças detectadas

echo "=== Validação completa ==="
```

- Execute esse workflow em todo PR de infra
- O `plan` deve ser revisado por humano antes do `apply`
- **Nunca** faça `apply` sem `plan` prévio revisado
