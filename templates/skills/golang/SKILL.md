---
name: golang
description: Go — project structure, interfaces, error handling, testing
---

# Go

Convenções e padrões obrigatórios para projetos Go.

## Estrutura de Projeto

```
project/
├── cmd/
│   └── api/
│       └── main.go          # entrypoint — só wiring e boot
├── internal/
│   ├── user/
│   │   ├── handler.go       # HTTP handlers
│   │   ├── service.go       # lógica de negócio
│   │   ├── repository.go    # acesso a dados
│   │   └── model.go         # structs do domínio
│   └── platform/
│       ├── database/        # setup do DB
│       └── config/          # parsing de config
├── pkg/                      # código reutilizável entre projetos
├── go.mod
└── go.sum
```

- `cmd/` — binários, um por subdiretório
- `internal/` — código privado do projeto (Go proíbe import externo)
- `pkg/` — código público reutilizável (usar com parcimônia)

## Interfaces — Pequenas e Focadas

```go
// Definir interfaces onde são CONSUMIDAS, não onde são implementadas
type UserRepository interface {
    GetByID(ctx context.Context, id int64) (*User, error)
    Create(ctx context.Context, user *User) error
}

type UserService struct {
    repo UserRepository  // depende da interface, não da implementação
}
```

- Interfaces pequenas (1-3 métodos) — composição sobre herança
- Definir no pacote **consumidor**, não no implementador
- `io.Reader`, `io.Writer` são os exemplos canônicos

## Tratamento de Erros

```go
// Erros tipados com wrapping
var ErrUserNotFound = errors.New("user not found")

func (s *UserService) GetByID(ctx context.Context, id int64) (*User, error) {
    user, err := s.repo.GetByID(ctx, id)
    if err != nil {
        return nil, fmt.Errorf("getting user %d: %w", id, err)  // %w para wrap
    }
    if user == nil {
        return nil, ErrUserNotFound
    }
    return user, nil
}

// No handler — checar tipo do erro
if errors.Is(err, ErrUserNotFound) {
    http.Error(w, "not found", http.StatusNotFound)
    return
}
```

- **Nunca** usar `panic` para erros de negócio — apenas para bugs irrecuperáveis
- Sempre wrappear com `%w` para manter a cadeia
- `errors.Is()` e `errors.As()` para verificar erros wrapeados

## Context — Sempre Propagar

```go
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()  // contexto do request
    user, err := h.service.GetByID(ctx, id)
    // ...
}
```

- `context.Context` é **sempre** o primeiro parâmetro
- Nunca armazenar context em structs
- Usar `context.WithTimeout` para operações com deadline

## CLIs com Cobra

```go
var rootCmd = &cobra.Command{
    Use:   "minha-cli",
    Short: "Descrição curta da CLI",
}

func main() {
    if err := rootCmd.Execute(); err != nil {
        os.Exit(1)
    }
}
```

## Testes — Table-Driven

```go
func TestUserService_GetByID(t *testing.T) {
    tests := []struct {
        name    string
        id      int64
        want    *User
        wantErr error
    }{
        {name: "encontrado", id: 1, want: &User{ID: 1, Name: "Ana"}, wantErr: nil},
        {name: "não encontrado", id: 999, want: nil, wantErr: ErrUserNotFound},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            svc := NewUserService(mockRepo)
            got, err := svc.GetByID(context.Background(), tt.id)

            assert.ErrorIs(t, err, tt.wantErr)
            assert.Equal(t, tt.want, got)
        })
    }
}
```

- **testify** para assertions mais legíveis
- **golangci-lint** no CI com config `.golangci.yml`
- **GoReleaser** para distribuição de binários

## Pegadinhas Conhecidas

| Problema | Solução |
|---|---|
| Interface nil vs pointer nil — `var x *Foo = nil; var i I = x; i != nil` é `true` | Retornar `nil` explícito no tipo interface |
| Goroutine leaks — goroutine órfã esperando forever | Sempre usar `ctx.Done()` ou `sync.WaitGroup` |
| `defer` em loops não executa até fim da função | Extrair corpo do loop para função separada |
| Shadowing com `:=` em if/for | `go vet` + `golangci-lint` detectam |
| `range` copia valores (antes do Go 1.22) | Usar índice para acessar elemento original |
