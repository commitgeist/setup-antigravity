---
name: postgres
description: PostgreSQL — queries, indexing, migrations, diagnostics
---

# PostgreSQL — Performance, Migrações e Diagnóstico

## Otimização de Queries

```sql
-- SEMPRE use EXPLAIN ANALYZE para entender o plano de execução real
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT u.name, o.total
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE o.created_at >= NOW() - INTERVAL '30 days'
  AND o.status = 'completed';
```

### O que observar no plano:

- **Seq Scan** em tabelas grandes → falta índice
- **Nested Loop** com tabela grande no inner → considere Hash Join
- **Rows estimadas vs reais** muito diferentes → `ANALYZE` na tabela
- **Buffers shared hit vs read** → cache miss alto indica I/O problem

## Estratégias de Índice

```sql
-- B-tree: padrão, ideal para =, <, >, BETWEEN, ORDER BY
CREATE INDEX idx_orders_user_id ON orders (user_id);

-- Índice composto: ordem importa — coluna mais seletiva primeiro
CREATE INDEX idx_orders_user_status ON orders (user_id, status);

-- Índice parcial: reduz tamanho quando filtro é frequente
CREATE INDEX idx_orders_pending ON orders (created_at)
WHERE status = 'pending';

-- GIN: para JSONB, arrays, full-text search
CREATE INDEX idx_users_metadata ON users USING GIN (metadata jsonb_path_ops);

-- Covering index (INCLUDE): evita table lookup
CREATE INDEX idx_orders_covering ON orders (user_id)
INCLUDE (total, status);
```

### Regras de indexação:

- Índice em toda FK referenciada em JOINs
- Não crie índices que não serão usados — cada um custa em escrita
- Verifique uso com `pg_stat_user_indexes` (veja seção Diagnóstico)

## Migrações Seguras (Zero Downtime)

### Adicionar coluna (seguro)

```sql
-- Seguro: NOT NULL com DEFAULT não bloqueia em PG 11+
ALTER TABLE users ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true;
```

### Adicionar coluna (cuidado em versões antigas)

```sql
-- PG < 11: adicione nullable primeiro, depois backfill em batches
ALTER TABLE users ADD COLUMN is_active BOOLEAN;

-- Backfill em lotes para não bloquear
UPDATE users SET is_active = true WHERE id BETWEEN 1 AND 10000;
UPDATE users SET is_active = true WHERE id BETWEEN 10001 AND 20000;
-- ...

ALTER TABLE users ALTER COLUMN is_active SET NOT NULL;
ALTER TABLE users ALTER COLUMN is_active SET DEFAULT true;
```

### Criar índice sem lock

```sql
-- CONCURRENTLY não bloqueia escritas (obrigatório em produção)
CREATE INDEX CONCURRENTLY idx_users_email ON users (email);
-- ATENÇÃO: se falhar, o índice fica INVALID — dropar e recriar
```

### Renomear coluna (perigoso)

- **Nunca** renomeie diretamente em prod — quebra queries em andamento
- Padrão: criar nova coluna → dual-write → migrar leituras → remover antiga

## Queries de Diagnóstico

### Conexões ativas

```sql
SELECT pid, usename, application_name, client_addr,
       state, query_start, NOW() - query_start AS duration,
       LEFT(query, 80) AS query_preview
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start;
```

### Queries de longa duração (> 1 minuto)

```sql
SELECT pid, usename, NOW() - query_start AS duration,
       LEFT(query, 120) AS query
FROM pg_stat_activity
WHERE state = 'active'
  AND NOW() - query_start > INTERVAL '1 minute'
ORDER BY duration DESC;
```

### Índices não utilizados

```sql
SELECT schemaname, relname AS table, indexrelname AS index,
       idx_scan AS scans, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Bloat de tabelas

```sql
SELECT schemaname, relname,
       n_live_tup, n_dead_tup,
       ROUND(n_dead_tup::numeric / NULLIF(n_live_tup, 0) * 100, 1) AS dead_pct,
       last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;
```

### Top queries por tempo (requer pg_stat_statements)

```sql
SELECT LEFT(query, 100) AS query,
       calls, ROUND(total_exec_time::numeric, 1) AS total_ms,
       ROUND(mean_exec_time::numeric, 1) AS mean_ms,
       rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

## Vacuum e Manutenção

```sql
-- Verificar configuração de autovacuum
SHOW autovacuum;
SHOW autovacuum_vacuum_threshold;
SHOW autovacuum_vacuum_scale_factor;

-- Para tabelas com muito UPDATE/DELETE, ajuste por tabela:
ALTER TABLE orders SET (
  autovacuum_vacuum_threshold = 50,
  autovacuum_vacuum_scale_factor = 0.05,  -- 5% ao invés do padrão 20%
  autovacuum_analyze_threshold = 50,
  autovacuum_analyze_scale_factor = 0.05
);

-- VACUUM FULL reconstrói a tabela — bloqueia, usar somente em manutenção
-- Prefira pg_repack para compactar sem downtime
```

## Connection Pooling

- Use **PgBouncer** ou pool nativo do framework (HikariCP, Npgsql pool)
- `max_connections` padrão do PG é 100 — insuficiente para apps com muitos pods
- Fórmula: `pool_size = (2 * num_cores) + num_disks` por instância da app
- Modo `transaction` no PgBouncer para máxima eficiência
- **Nunca** use `session` mode com connection pooling em apps stateless
