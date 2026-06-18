---
name: react
description: React — Vite, hooks, state management, testing
---

# React

Convenções e padrões obrigatórios para projetos React.

## Setup Base

- **Vite** sempre — CRA está deprecado
- **TypeScript strict** — sem exceções
- **Named exports** — nunca `export default` (facilita refactoring e imports)

## Estrutura por Feature

```
src/
├── features/
│   ├── users/
│   │   ├── components/
│   │   │   ├── UserList.tsx
│   │   │   └── UserCard.tsx
│   │   ├── hooks/
│   │   │   └── useUsers.ts
│   │   ├── api/
│   │   │   └── users.api.ts
│   │   ├── types.ts
│   │   └── index.ts          # barrel export
│   └── orders/
├── shared/
│   ├── components/            # componentes genéricos (Button, Modal)
│   ├── hooks/
│   └── utils/
├── app/
│   ├── routes.tsx
│   └── providers.tsx
└── main.tsx
```

## Componentes — Padrões

```tsx
// ❌ Errado — não usar React.FC
const UserCard: React.FC<Props> = ({ name }) => { ... }

// ✅ Correto — tipagem direta nas props
export function UserCard({ name, email }: UserCardProps) {
  return (
    <article>
      <h3>{name}</h3>
      <p>{email}</p>
    </article>
  );
}
```

- Sem `React.FC` — adiciona `children` implícito e dificulta generics
- Props com sufixo `Props` — `UserCardProps`, `ButtonProps`
- Componentes são funções, não arrow functions atribuídas a variáveis

## Estado do Servidor — TanStack Query

```tsx
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";

export function useUsers() {
  return useQuery({
    queryKey: ["users"],
    queryFn: () => api.getUsers(),
    staleTime: 5 * 60 * 1000,  // 5 min
  });
}

export function useCreateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: api.createUser,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["users"] });
    },
  });
}
```

- **TanStack Query** para estado do servidor — nunca `useEffect` + `useState` para fetch
- Estado local (`useState`) apenas para UI (modais, tabs, formulários)
- Zustand para estado global complexo (raro — questionar a necessidade)

## Formulários — React Hook Form + Zod

```tsx
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";

const schema = z.object({
  name: z.string().min(2, "Nome deve ter ao menos 2 caracteres"),
  email: z.string().email("Email inválido"),
});

type FormData = z.infer<typeof schema>;

export function UserForm({ onSubmit }: UserFormProps) {
  const { register, handleSubmit, formState: { errors } } = useForm<FormData>({
    resolver: zodResolver(schema),
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input {...register("name")} />
      {errors.name && <span>{errors.name.message}</span>}
      <button type="submit">Salvar</button>
    </form>
  );
}
```

## Testes — Vitest + Testing Library

```tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, it, expect } from "vitest";

describe("UserCard", () => {
  it("deve exibir nome e email do usuário", () => {
    render(<UserCard name="Ana" email="ana@test.com" />);

    expect(screen.getByText("Ana")).toBeInTheDocument();
    expect(screen.getByText("ana@test.com")).toBeInTheDocument();
  });
});
```

- Testar **comportamento**, não implementação
- Queries por role/texto — `getByRole`, `getByText` (nunca `getByTestId` como primeira opção)

## Pegadinhas Conhecidas

| Problema | Solução |
|---|---|
| `useEffect` deps faltando → bugs silenciosos | Plugin ESLint `react-hooks/exhaustive-deps` obrigatório |
| `key` em listas — usar ID, nunca índice | `{items.map(item => <Card key={item.id} />)}` |
| StrictMode causa mount duplo em dev | É intencional — não "consertar" removendo StrictMode |
| Stale closures em handlers com state | Usar `useRef` ou garantir deps corretas no `useCallback` |
| Re-renders desnecessários | `React.memo` com cuidado, memoizar callbacks e valores derivados |
