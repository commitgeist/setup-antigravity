---
name: nextjs
description: Next.js — App Router, Server Components, Server Actions
---

# Next.js

Convenções e padrões obrigatórios para projetos Next.js.

## Regra Fundamental

- **App Router** sempre — Pages Router é legado
- **Server Components** por padrão — Client Components APENAS para interatividade
- `'use client'` é exceção, não regra

## Estrutura do App Router

```
app/
├── layout.tsx                # layout raiz — providers, fontes, metadata
├── page.tsx                  # rota /
├── loading.tsx               # fallback de loading global
├── error.tsx                 # error boundary global ('use client' obrigatório)
├── not-found.tsx             # página 404 customizada
├── users/
│   ├── page.tsx              # rota /users
│   ├── [id]/
│   │   ├── page.tsx          # rota /users/:id
│   │   └── loading.tsx       # loading específico
│   └── actions.ts            # Server Actions do domínio
├── api/
│   └── webhooks/
│       └── route.ts          # Route Handler para webhooks externos
└── globals.css
```

## Server Components (Padrão)

```tsx
// app/users/page.tsx — Server Component (sem 'use client')
import { getUsers } from "@/lib/users";

export default async function UsersPage() {
  const users = await getUsers();  // fetch direto — sem useEffect, sem useState

  return (
    <main>
      <h1>Usuários</h1>
      <UserList users={users} />
    </main>
  );
}
```

- Fetch de dados diretamente no componente — sem hooks, sem loading state manual
- Acesso direto a DB, filesystem, env vars secretas
- Zero JS enviado ao browser para Server Components

## Client Components — Apenas Quando Necessário

```tsx
"use client";  // APENAS quando precisa de interatividade

import { useState } from "react";

export function SearchFilter({ onSearch }: SearchFilterProps) {
  const [query, setQuery] = useState("");

  return (
    <input
      value={query}
      onChange={(e) => setQuery(e.target.value)}
      onKeyDown={(e) => e.key === "Enter" && onSearch(query)}
    />
  );
}
```

Usar `'use client'` apenas para: `useState`, `useEffect`, event handlers, browser APIs.

## Server Actions com Validação

```tsx
// app/users/actions.ts
"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";

const CreateUserSchema = z.object({
  name: z.string().min(2),
  email: z.string().email(),
});

export async function createUser(formData: FormData) {
  const parsed = CreateUserSchema.safeParse({
    name: formData.get("name"),
    email: formData.get("email"),
  });

  if (!parsed.success) {
    return { error: parsed.error.flatten() };
  }

  await db.user.create({ data: parsed.data });
  revalidatePath("/users");
}
```

- **Sempre** validar input com Zod — Server Actions são endpoints públicos
- `revalidatePath` / `revalidateTag` após mutações

## Metadata API para SEO

```tsx
import { Metadata } from "next";

export const metadata: Metadata = {
  title: "Usuários | Meu App",
  description: "Lista de usuários do sistema",
};

// Metadata dinâmica
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const user = await getUser(params.id);
  return { title: `${user.name} | Meu App` };
}
```

## Streaming com Suspense

```tsx
import { Suspense } from "react";

export default function DashboardPage() {
  return (
    <main>
      <h1>Dashboard</h1>
      <Suspense fallback={<CardSkeleton />}>
        <SlowMetricsCard />  {/* carrega independente */}
      </Suspense>
      <Suspense fallback={<TableSkeleton />}>
        <SlowDataTable />
      </Suspense>
    </main>
  );
}
```

## Pegadinhas Conhecidas

| Problema | Solução |
|---|---|
| `fetch` no App Router cacheia por padrão (Next 14) | Usar `{ cache: 'no-store' }` ou `revalidate: 0` quando necessário |
| `revalidatePath` não funciona em try/catch | Chamar fora do try/catch ou usar `redirect()` |
| `'use client'` contamina — todo componente filho vira client | Mover `'use client'` para o menor componente possível |
| Route segments dinâmicos `[id]` são strings | Sempre converter: `const id = Number(params.id)` |
| `cookies()` / `headers()` tornam a rota dinâmica | Usar apenas quando realmente precisa de dados por request |
| Importar Server Component dentro de Client Component | Passar como `children` — composição resolve |
