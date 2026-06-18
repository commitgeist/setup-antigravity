---
name: aws-infra
description: AWS infrastructure — IAM, S3, ECS, CloudFormation, OIDC
---

# AWS — Infraestrutura e Segurança

## IAM — Least Privilege

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::meu-bucket/prefix/*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "us-east-1"
        }
      }
    }
  ]
}
```

- **Sempre** especifique Resource com ARN exato (nunca `*` em produção)
- Use `Condition` para restringir por região, IP, tag, etc.
- Prefira IAM Roles sobre IAM Users para workloads
- Revise com `IAM Access Analyzer` antes de deploy

## OIDC Federation para CI/CD (Regra Inviolável)

```yaml
# Trust policy para Azure DevOps
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/vstoken.dev.azure.com/ORG_ID"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "vstoken.dev.azure.com/ORG_ID:sub": "sc://org/project/service-connection"
      }
    }
  }]
}
```

- **NUNCA** use long-lived access keys em pipelines
- Legacy accounts: role dedicada ao service connection
- New accounts: role com OIDC federation
- Template compartilhado: `steps/aws-login-oidc.yaml`

## Role Chaining — Pegadinha Crítica

```bash
# CORRETO: usar bash com env explícito após assume-role
- bash: |
    aws sts get-caller-identity
    aws s3 ls s3://meu-bucket/
  env:
    AWS_ACCESS_KEY_ID: $(AWS_ACCESS_KEY_ID)
    AWS_SECRET_ACCESS_KEY: $(AWS_SECRET_ACCESS_KEY)
    AWS_SESSION_TOKEN: $(AWS_SESSION_TOKEN)

# ERRADO: AWSCLI@1 sobrescreve as credenciais do role chaining
# - task: AWSCLI@1    # NUNCA usar após assume-role
```

## S3 — Bucket Policies

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUnencryptedUploads",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::meu-bucket/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "aws:kms"
        }
      }
    },
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": ["arn:aws:s3:::meu-bucket", "arn:aws:s3:::meu-bucket/*"],
      "Condition": {
        "Bool": { "aws:SecureTransport": "false" }
      }
    }
  ]
}
```

- Block Public Access **sempre** ativado (a menos que CDN necessário)
- Versionamento ativado para buckets críticos
- Lifecycle rules para controlar custos (transition para Glacier, expiration)

## ECS Fargate — Task Definition

```json
{
  "family": "minha-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::ACCOUNT:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::ACCOUNT:role/ecsTaskRole",
  "containerDefinitions": [{
    "name": "app",
    "image": "ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/myapp:v1.2.3",
    "portMappings": [{ "containerPort": 8080 }],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/minha-task",
        "awslogs-region": "us-east-1",
        "awslogs-stream-prefix": "app"
      }
    },
    "secrets": [{
      "name": "DB_PASSWORD",
      "valueFrom": "arn:aws:ssm:us-east-1:ACCOUNT:parameter/prod/db-password"
    }]
  }]
}
```

- `executionRoleArn`: para ECR pull e CloudWatch Logs
- `taskRoleArn`: para acessar recursos AWS pela aplicação
- Secrets via SSM Parameter Store ou Secrets Manager (nunca env vars plain text)
- Env vars nested no .NET ECS: separador `__` (double underscore)

## CloudFormation

- **Sempre** passe `CAPABILITY_NAMED_IAM` ao criar/atualizar stacks com recursos IAM
- Use `DeletionPolicy: Retain` em recursos críticos
- Valide com `aws cloudformation validate-template` antes do deploy

## VPC e Security Groups

```hcl
# Regra: Security groups são stateful — só defina ingress, return traffic é automático
# Princípio: deny all, allow específico
resource "aws_security_group_rule" "app_ingress" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id  # Ref por SG, não CIDR
  security_group_id        = aws_security_group.app.id
}
```

## Parameter Store vs Secrets Manager

| Aspecto            | Parameter Store         | Secrets Manager            |
|--------------------|-------------------------|----------------------------|
| Custo              | Gratuito (standard)     | $0.40/secret/mês           |
| Rotação automática | Não                     | Sim (Lambda)               |
| Uso ideal          | Config, feature flags   | Senhas DB, API keys        |
| Cross-account      | Limitado                | Suporte nativo             |
