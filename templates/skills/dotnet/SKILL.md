---
name: dotnet
description: .NET — Minimal API, C# patterns, Entity Framework
---

# .NET / C#

Convenções e padrões obrigatórios para projetos .NET 8+.

## Configuração de Projeto

### .csproj — Sempre restritivo

```xml
<PropertyGroup>
  <TargetFramework>net8.0</TargetFramework>
  <Nullable>enable</Nullable>
  <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  <ImplicitUsings>enable</ImplicitUsings>
  <InvariantGlobalization>true</InvariantGlobalization>
</PropertyGroup>
```

- `Nullable` enable — sem exceção
- `TreatWarningsAsErrors` — warnings acumulados viram dívida técnica

## Minimal API — Padrões

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddOptions<DatabaseOptions>()
    .BindConfiguration("Database")
    .ValidateDataAnnotations()
    .ValidateOnStart();  // fail fast no boot

builder.Services.AddScoped<IUserRepository, UserRepository>();

var app = builder.Build();

app.MapGet("/users/{id:int}", async (int id, IUserRepository repo, CancellationToken ct) =>
{
    var user = await repo.GetByIdAsync(id, ct);
    return user is null ? Results.NotFound() : Results.Ok(user);
});
```

### Options Pattern com ValidateOnStart

```csharp
public class DatabaseOptions
{
    [Required] public string ConnectionString { get; init; } = "";
    [Range(1, 100)] public int MaxPoolSize { get; init; } = 20;
}
```

## Validação com FluentValidation

```csharp
public record CreateUserRequest(string Name, string Email);

public class CreateUserValidator : AbstractValidator<CreateUserRequest>
{
    public CreateUserValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
    }
}
```

- **Record types** para DTOs — imutáveis por padrão
- Injetar `IValidator<T>` nos endpoints

## Entity Framework Core

```csharp
public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}
```

- Configurações em classes `IEntityTypeConfiguration<T>` separadas
- Migrations versionadas e commitadas — nunca `EnsureCreated()` em produção
- Sempre propagar `CancellationToken` nas queries async

## Testes com xUnit + NSubstitute

```csharp
public class UserServiceTests
{
    private readonly IUserRepository _repo = Substitute.For<IUserRepository>();
    private readonly UserService _sut;

    public UserServiceTests() => _sut = new UserService(_repo);

    [Fact]
    public async Task GetById_WhenNotFound_ReturnsNull()
    {
        _repo.GetByIdAsync(1, Arg.Any<CancellationToken>()).Returns((User?)null);

        var result = await _sut.GetByIdAsync(1, CancellationToken.None);

        result.Should().BeNull();
    }
}
```

- **xUnit** + **NSubstitute** + **FluentAssertions**
- Nomear: `Método_Cenário_ResultadoEsperado`

## Pegadinhas Conhecidas

| Problema | Solução |
|---|---|
| .NET 8+ em container non-root escuta na **8080**, não 80 | Ajustar `targetPort: 8080` no Service K8s |
| `HttpClient.BaseAddress` precisa terminar com `/` | `new Uri("https://api.example.com/v1/")` — sempre com barra |
| Path no `PostAsync` NÃO pode começar com `/` | `await client.PostAsync("users", content)` — sem barra |
| Env vars nested em ECS/containers usam `__` | `Database__ConnectionString` → `Database:ConnectionString` |
| `CancellationToken` não propagado | Sempre aceitar e passar `ct` em toda a cadeia async |
| `IDisposable` não descartado | Usar `await using` e verificar com analyzers |
