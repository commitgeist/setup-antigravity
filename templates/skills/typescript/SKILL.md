---
name: typescript
description: TypeScript/Node.js — strict mode, patterns, validation
---

# TypeScript / Node.js

Convenções e padrões obrigatórios para projetos TypeScript.

## Configuração Base

### tsconfig.json — Sempre strict

```jsonc
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "forceConsistentCasingInFileNames": true,
    "esModuleInterop": true,
    "moduleResolution": "bundler",
    "target": "ES2022",
    "paths": { "@/*": ["./src/*"] }
  }
}
```

### Tooling

- **ESLint** + **Prettier** configurados e rodando no CI
- `eslint-config-prettier` para evitar conflitos
- Scripts obrigatórios no `package.json`: `lint`, `format`, `typecheck`, `test`

## Validação em Runtime

Usar **Zod** para validar dados externos (API, env, arquivos):

```typescript
import { z } from "zod";

const EnvSchema = z.object({
  DATABASE_URL: z.string().url(),
  PORT: z.coerce.number().default(3000),
  NODE_ENV: z.enum(["development", "staging", "production"]),
});

// Validar no boot — fail fast
export const env = EnvSchema.parse(process.env);
```

## Tratamento de Erros Tipado

```typescript
export class AppError extends Error {
  constructor(
    public readonly code: string,
    public readonly message: string,
    public readonly statusCode: number = 500,
    public readonly cause?: unknown
  ) {
    super(message);
    this.name = "AppError";
  }
}

// Uso
throw new AppError("USER_NOT_FOUND", "Usuário não encontrado", 404);
```

## Organização de Código

- **Path aliases**: `@/` aponta para `src/` — nunca `../../../`
- **Barrel exports**: um `index.ts` por módulo exportando a API pública
- **Named exports** sempre — evitar `export default`
- Estrutura por feature, não por tipo de arquivo

## Testes com Vitest/Jest

```typescript
import { describe, it, expect } from "vitest";

describe("UserService", () => {
  it("deve lançar AppError quando usuário não existe", async () => {
    const service = new UserService(mockRepo);

    await expect(service.findById("inexistente")).rejects.toThrow(AppError);
  });
});
```

- Padrão **AAA** (Arrange, Act, Assert)
- Nomear testes de forma descritiva: `deve [resultado] quando [condição]`
- Mocks tipados — nunca `as any` em mocks

## Pegadinhas Conhecidas

| Problema | Solução |
|---|---|
| `any` é vírus — se espalha e mata type safety | Usar `unknown` + narrowing ou generics |
| `as` esconde erros em tempo de compilação | Preferir type guards (`is`, `satisfies`) |
| ESM vs CJS causa erros misteriosos | Definir `"type": "module"` no package.json e ser consistente |
| `===` vs `==` | Sempre `===`, ESLint `eqeqeq` rule |
| Promises não tratadas | Sempre `await` ou `.catch()`, usar `no-floating-promises` |
| `Object.keys()` retorna `string[]`, não `(keyof T)[]` | Criar helper tipado ou usar `as` com cuidado |
