---
name: azure-pipelines
description: Azure Pipelines — YAML templates, OIDC, variable groups
---

# Azure Pipelines — CI/CD

## Estrutura de Pipeline YAML

```yaml
trigger:
  branches:
    include: [main]
  paths:
    exclude: [docs/*, README.md]

pool:
  name: custom   # K8s agents no prcp1zu1aks001

variables:
  - group: MyApp-Production    # Variable Group — nunca hardcode secrets
  - name: buildConfiguration
    value: Release

stages:
  - stage: Build
    jobs:
      - job: BuildAndTest
        steps:
          - template: steps/build.yaml
            parameters:
              project: src/MyApp

  - stage: Deploy
    dependsOn: Build
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: DeployProd
        environment: production   # Gate de aprovação configurado no environment
        strategy:
          runOnce:
            deploy:
              steps:
                - template: steps/deploy.yaml
```

## Template Reuse — Steps/Jobs/Stages

```yaml
# steps/build.yaml — template reutilizável
parameters:
  - name: project
    type: string

steps:
  - task: DotNetCoreCLI@2
    displayName: Restore
    inputs:
      command: restore
      projects: ${{ parameters.project }}/*.csproj

  - task: DotNetCoreCLI@2
    displayName: Build
    inputs:
      command: build
      projects: ${{ parameters.project }}/*.csproj
      arguments: '--configuration Release --no-restore'

  - task: DotNetCoreCLI@2
    displayName: Test
    inputs:
      command: test
      projects: ${{ parameters.project }}.Tests/*.csproj
      arguments: '--no-build --configuration Release'
```

- Templates ficam em `Infrastructure/pipelines/`
- Organize por tipo: `steps/`, `jobs/`, `stages/`
- Parametrize tudo que varia entre ambientes

## OIDC Auth para AWS

```yaml
# steps/aws-login-oidc.yaml
parameters:
  - name: serviceConnection
    type: string
  - name: awsRegion
    type: string
    default: us-east-1

steps:
  - task: AWSShellScript@1
    displayName: AWS OIDC Login
    inputs:
      awsCredentials: ${{ parameters.serviceConnection }}
      regionName: ${{ parameters.awsRegion }}
      scriptType: inline
      inlineScript: |
        echo "##vso[task.setvariable variable=AWS_ACCESS_KEY_ID]$AWS_ACCESS_KEY_ID"
        echo "##vso[task.setvariable variable=AWS_SECRET_ACCESS_KEY;issecret=true]$AWS_SECRET_ACCESS_KEY"
        echo "##vso[task.setvariable variable=AWS_SESSION_TOKEN;issecret=true]$AWS_SESSION_TOKEN"

  # Após isso, use bash com env: explícito — NUNCA AWSCLI@1
  - bash: |
      aws sts get-caller-identity
    displayName: Verify AWS Identity
    env:
      AWS_ACCESS_KEY_ID: $(AWS_ACCESS_KEY_ID)
      AWS_SECRET_ACCESS_KEY: $(AWS_SECRET_ACCESS_KEY)
      AWS_SESSION_TOKEN: $(AWS_SESSION_TOKEN)
```

## Variable Groups — Regras

- Secrets **somente** em Variable Groups vinculados a Key Vault
- Nunca hardcode secrets no YAML da pipeline
- Separe variable groups por ambiente: `MyApp-Dev`, `MyApp-QA`, `MyApp-Production`
- Use `issecret=true` ao setar variáveis sensíveis via `##vso`

## Agent Pools

| Pool            | Infra                          | Uso                        |
|-----------------|--------------------------------|----------------------------|
| `custom`        | K8s Deployment, 5 réplicas     | Builds padrão, CI          |
| `Docker_Agent`  | VMSS, autoscale SaveMoney      | Builds com Docker           |
| `Linux_Agents`  | VMSS, specs maiores            | Builds pesados, Terraform   |

- Pool `custom` roda no `prcp1zu1aks001`, namespace `devopscustomagents`
- VMSS pools escalam automaticamente conforme demanda

## Environment Approvals

```yaml
# Configurar no Azure DevOps UI:
# Pipelines > Environments > production > Approvals and checks
# - Approval: pelo menos 1 reviewer
# - Branch control: somente main
# - Business hours: opcional para deploys em prod
```

- **Toda** pipeline de produção deve ter gate de aprovação humana
- Configure branch control para aceitar apenas `main`

## Artifact Publishing

```yaml
- task: PublishPipelineArtifact@1
  displayName: Publish Artifacts
  inputs:
    targetPath: $(Build.ArtifactStagingDirectory)
    artifact: drop
    publishLocation: pipeline
```

## Pegadinhas Conhecidas

- **`Rerun failed jobs` NÃO recarrega templates atualizados** — sempre use `Run new`
- `condition: succeeded()` é implícito — mas seja explícito em stages com dependências
- Variables definidas em runtime (`##vso`) não estão disponíveis no mesmo step
- Templates com `parameters` de tipo `object` precisam de default vazio: `default: {}`
- YAML anchors (`&` e `*`) **não são suportados** — use templates ao invés disso
