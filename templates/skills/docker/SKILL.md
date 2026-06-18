---
name: docker
description: Dockerfile best practices, multi-stage builds, security
---

# Docker — Builds, Segurança e Otimização

## Multi-Stage Build — Padrão Base

```dockerfile
# === Stage 1: Build ===
FROM node:20-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev          # npm ci (não npm install) para builds reproduzíveis
COPY . .
RUN npm run build

# === Stage 2: Runtime ===
FROM node:20-slim AS runtime
WORKDIR /app
RUN addgroup --system app && adduser --system --ingroup app app
COPY --from=build --chown=app:app /app/dist ./dist
COPY --from=build --chown=app:app /app/node_modules ./node_modules
USER app
EXPOSE 3000
CMD ["node", "dist/index.js"]
```

## Multi-Stage — .NET

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY *.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
RUN adduser --disabled-password --no-create-home appuser
COPY --from=build --chown=appuser /app/publish .
USER appuser
EXPOSE 8080
# .NET 8+ escuta em 8080 por padrão em containers (non-root)
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

## Multi-Stage — Python

```dockerfile
FROM python:3.12-slim AS build
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim AS runtime
WORKDIR /app
RUN adduser --disabled-password --no-create-home appuser
COPY --from=build /install /usr/local
COPY --chown=appuser . .
USER appuser
EXPOSE 8000
CMD ["gunicorn", "app:create_app()", "-b", "0.0.0.0:8000"]
```

## Multi-Stage — Go

```dockerfile
FROM golang:1.22 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/server .

FROM gcr.io/distroless/static-debian12 AS runtime
COPY --from=build /app/server /server
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/server"]
```

## Otimização de Layer Cache

1. Copie **primeiro** arquivos de dependência (`package.json`, `requirements.txt`, `go.mod`)
2. Rode o install de dependências (layer cacheada se deps não mudaram)
3. Copie o código fonte **depois**
4. Ordene instruções da menos mutável para a mais mutável

## .dockerignore (Obrigatório)

```
.git
node_modules
__pycache__
*.pyc
.env
.env.*
*.tfstate
*.tfstate.backup
dist/
bin/
obj/
```

## Docker Compose para Desenvolvimento

```yaml
services:
  app:
    build:
      context: .
      target: build   # Use stage de build para dev (com ferramentas)
    volumes:
      - .:/app
      - /app/node_modules
    ports:
      - "3000:3000"
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: devdb
      POSTGRES_USER: devuser
      POSTGRES_PASSWORD: devpass   # Apenas dev local — nunca em prod
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U devuser -d devdb"]
      interval: 5s
      retries: 5
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

## Regras de Segurança

- **Sempre** rode como non-root (`USER appuser`)
- **Nunca** use tag `:latest` — use SHA ou versão exata
- **Nunca** copie secrets para dentro da imagem (use runtime env vars ou mounted secrets)
- Use imagens `-slim` ou `distroless` para runtime
- Não instale ferramentas desnecessárias no stage de runtime

## Validação (executar em CI)

```bash
# Lint do Dockerfile
hadolint Dockerfile

# Scan de vulnerabilidades na imagem construída
trivy image --severity HIGH,CRITICAL myapp:latest
# ATENÇÃO: trivy pinado em v0.69.2 (v0.69.4–v0.69.6 comprometidas)
```

## Pegadinhas Conhecidas

- `npm ci` (não `npm install`) — garantia de build reproduzível
- Alpine usa musl, não glibc — pode quebrar binários nativos (Python, Node addons)
- `.NET 8+` em container escuta na porta **8080** por padrão (non-root)
- `COPY . .` invalida cache se qualquer arquivo mudar — copie deps primeiro
