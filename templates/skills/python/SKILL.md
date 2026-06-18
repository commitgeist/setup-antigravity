---
name: python
description: Python — FastAPI, typing, Pydantic, async patterns
---

# Python

Convenções e padrões obrigatórios para projetos Python.

## Configuração de Projeto

### pyproject.toml (nunca setup.py)

```toml
[project]
name = "meu-servico"
version = "0.1.0"
requires-python = ">=3.12"

[tool.ruff]
target-version = "py312"
line-length = 100

[tool.ruff.lint]
select = ["E", "F", "W", "I", "UP", "S", "B", "A", "C4", "RUF"]

[tool.mypy]
strict = true
warn_return_any = true
disallow_untyped_defs = true
```

### Tooling

- **Ruff** para linting E formatting (substitui Black + isort + Flake8)
- **mypy** em modo strict — sem exceções
- **uv** ou **poetry** para gerenciar dependências (lockfile sempre commitado)

## Validação com Pydantic

```python
from pydantic import BaseModel, Field
from pydantic_settings import BaseSettings

class DatabaseConfig(BaseSettings):
    model_config = {"env_prefix": "DB_"}

    host: str
    port: int = 5432
    name: str
    password: str = Field(repr=False)  # nunca logar

class UserCreate(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    email: str = Field(pattern=r"^[\w\.-]+@[\w\.-]+\.\w+$")
```

## Erros Tipados

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class AppError(Exception):
    code: str
    message: str
    status_code: int = 500

class NotFoundError(AppError):
    status_code: int = 404

# Uso
raise NotFoundError(code="USER_NOT_FOUND", message="Usuário não encontrado")
```

## FastAPI — Padrões

```python
from typing import Annotated
from fastapi import Depends, FastAPI

app = FastAPI()

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with session_factory() as session:
        yield session

DbSession = Annotated[AsyncSession, Depends(get_db)]

@app.get("/users/{user_id}")
async def get_user(user_id: int, db: DbSession) -> UserResponse:
    user = await db.get(User, user_id)
    if not user:
        raise NotFoundError(code="USER_NOT_FOUND", message="Usuário não encontrado")
    return UserResponse.model_validate(user)
```

- Usar `Annotated[..., Depends()]` — mais limpo e reutilizável
- Routers organizados por domínio (`users/router.py`, `orders/router.py`)

## Testes com pytest

```python
import pytest
from httpx import ASGITransport, AsyncClient

@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as ac:
        yield ac

@pytest.mark.anyio
async def test_get_user_not_found(client: AsyncClient) -> None:
    response = await client.get("/users/999")
    assert response.status_code == 404
    assert response.json()["code"] == "USER_NOT_FOUND"
```

## Pegadinhas Conhecidas

| Problema | Solução |
|---|---|
| `async def` sem `await` dentro — roda síncrono e bloqueia | Sempre verificar que funções async usam `await` |
| `BaseSettings` v2 mudou API (Pydantic v2) | Instalar `pydantic-settings` separado, usar `model_config` |
| `datetime.utcnow()` deprecado no 3.12+ | Usar `datetime.now(UTC)` com `from datetime import UTC` |
| Mutable default args (`def f(x=[])`) | Usar `None` + atribuição dentro da função |
| `import *` quebra type checking | Sempre imports explícitos |
| SQLAlchemy lazy loading em async | Usar `selectinload()` / `joinedload()` explicitamente |
