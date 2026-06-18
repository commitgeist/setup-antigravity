---
name: testing
description: Testing — pyramid, patterns, frameworks, anti-patterns
---

# Testing

Convenções e padrões obrigatórios para testes em qualquer stack.

## Pirâmide de Testes

```
        ╱ E2E ╲             → poucos, lentos, caros (Playwright, Cypress)
       ╱────────╲
      ╱Integration╲        → médios, testam contratos entre módulos
     ╱──────────────╲
    ╱   Unit Tests    ╲     → muitos, rápidos, isolados
   ╱────────────────────╲
```

- **Unit**: função/classe isolada, sem I/O — deve rodar em <10ms
- **Integration**: módulos juntos, pode usar DB real (testcontainers) ou HTTP mock
- **E2E**: fluxo completo do usuário — usar com parcimônia

## Padrão AAA (Arrange, Act, Assert)

```
// Arrange — preparar dados e dependências
// Act     — executar a ação sendo testada
// Assert  — verificar o resultado
```

Cada teste deve ter **exatamente uma razão para falhar**.

## Nomenclatura Descritiva

```
✅ "deve retornar 404 quando usuário não existe"
✅ "deve calcular desconto quando cupom é válido"
✅ "deve lançar erro quando email é inválido"

❌ "test1"
❌ "testUserService"
❌ "should work"
```

Padrão: `deve [resultado esperado] quando [condição]`

## Decisão: Mock vs Real

| Dependência | Decisão | Motivo |
|---|---|---|
| Banco de dados | 🔶 Mock (unit) / Real (integration) | Testcontainers para integration |
| HTTP externo | 🔴 Mock sempre | Instável, lento, custos |
| Filesystem | 🔴 Mock | Evitar side effects |
| Relógio/tempo | 🔴 Mock (injetar) | Testes determinísticos |
| Logger | 🟢 Real | Sem side effects relevantes |
| Hasher/crypto | 🟢 Real | Leve e determinístico |
| Fila de mensagens | 🔶 Mock (unit) / Real (integration) | Testcontainers para integration |

## Exemplos por Framework

### Vitest (TypeScript)

```typescript
describe("OrderService", () => {
  it("deve aplicar desconto quando cupom é válido", () => {
    const service = new OrderService(mockCouponRepo);
    mockCouponRepo.findByCode.mockResolvedValue({ discount: 0.1 });

    const total = await service.calculateTotal(items, "DESCONTO10");

    expect(total).toBe(900);  // 1000 - 10%
  });
});
```

### pytest (Python)

```python
class TestOrderService:
    def test_deve_aplicar_desconto_quando_cupom_valido(
        self, order_service: OrderService, mock_coupon_repo: Mock
    ) -> None:
        mock_coupon_repo.find_by_code.return_value = Coupon(discount=Decimal("0.1"))

        total = order_service.calculate_total(items, "DESCONTO10")

        assert total == Decimal("900")
```

### xUnit (C#)

```csharp
[Fact]
public async Task CalculateTotal_WithValidCoupon_AppliesDiscount()
{
    _couponRepo.FindByCodeAsync("DESCONTO10").Returns(new Coupon(0.1m));

    var total = await _sut.CalculateTotal(items, "DESCONTO10");

    total.Should().Be(900m);
}
```

### Go

```go
func TestOrderService_CalculateTotal_WithValidCoupon(t *testing.T) {
    repo := &mockCouponRepo{coupon: &Coupon{Discount: 0.1}}
    svc := NewOrderService(repo)

    total, err := svc.CalculateTotal(context.Background(), items, "DESCONTO10")

    require.NoError(t, err)
    assert.Equal(t, 900.0, total)
}
```

## Anti-Patterns — Evitar Sempre

| Anti-Pattern | Problema | Solução |
|---|---|---|
| Testar implementação | Quebra quando refatora sem mudar comportamento | Testar input → output |
| Testes flaky | Falham aleatoriamente, destroem confiança | Isolar, usar mocks de tempo/rede |
| Estado compartilhado | Testes dependem da ordem de execução | Setup/teardown por teste |
| `sleep()` em testes | Lento e não determinístico | Usar polling/retry com timeout curto |
| Mock de tudo | Testa apenas se mocks estão configurados certo | Mock só o necessário (ver tabela) |
| Teste sem assertion | Sempre passa, falsa segurança | Cada teste DEVE ter assert |
| Copiar testes e mudar pouco | Difícil manter, esconde padrões | Table-driven tests ou parametrize |

## Cobertura

- **Alvo**: cobertura **significativa**, não 100%
- Cobrir: caminhos críticos, edge cases, erros
- Não cobrir: getters/setters triviais, código gerado, wiring de DI
- Mínimo sugerido: **80%** em lógica de negócio
- Usar cobertura como **guia**, não como **meta** — testes ruins com 100% são piores que bons com 70%
