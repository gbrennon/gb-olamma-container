# TypeScript Standards

## tsconfig.json Baseline

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true
  }
}
```

`strict: true` is non-negotiable. `noUncheckedIndexedAccess` prevents the most common runtime crash class.

## Branded Types for Domain Identifiers

```typescript
type Brand<T, B extends string> = T & { readonly _brand: B };

type OrderId    = Brand<string, "OrderId">;
type CustomerId = Brand<string, "CustomerId">;

const OrderId = (value: string): OrderId => value as OrderId;
```

Never use raw `string` or `number` for domain identifiers.

## Value Objects

```typescript
type Amount = Brand<number, "Amount">;

const Amount = {
  of(value: number): Result<Amount, DomainError> {
    return value > 0
      ? ok(value as Amount)
      : err(new InvalidAmountError(value));
  }
};
```

All domain objects are `readonly`. Mutation is a bug in the domain layer.

## Port Definition

```typescript
// ports/order-repository.ts
export interface OrderRepository {
  save(order: Order): Promise<void>;
  findById(id: OrderId): Promise<Order | null>;
}
```

Ports live in `application/ports/`. Adapters live in `infrastructure/` and implement these interfaces.
Never `import` from `infrastructure/` inside `domain/` or `application/`.

## Result Type for Error Handling

Use `neverthrow` or a lightweight custom Result:

```typescript
import { ok, err, Result } from "neverthrow";

async function placeOrder(
  id: OrderId,
  quantity: number,
): Promise<Result<Order, DomainError>> {
  const stock = await repository.findStock(id);
  if (stock < quantity) {
    return err(new InsufficientStockError(quantity, stock));
  }
  // ...
  return ok(order);
}
```

Never `throw` inside domain or application logic. Reserve thrown errors for infrastructure boundary failures.

## Dependency Injection

Use constructor injection. Wire dependencies in a composition root (`main.ts` or `container.ts`).

```typescript
// composition root
const repository = new PostgresOrderRepository(db);
const service    = new OrderService(repository);
const handler    = new PlaceOrderHandler(service);
```

No `new ConcreteService()` inside domain or application classes.

## Testing

```typescript
// Unit test — mock the interface, not the class
const mockRepo: OrderRepository = {
  save: jest.fn(),
  findById: jest.fn().mockResolvedValue(null),
};

describe("OrderService", () => {
  it("should return InsufficientStockError when stock is zero", async () => {
    mockRepo.findById = jest.fn().mockResolvedValue({ stock: 0 });
    const service = new OrderService(mockRepo);
    const result = await service.placeOrder(orderId, 1);
    expect(result.isErr()).toBe(true);
    expect(result._unsafeUnwrapErr()).toBeInstanceOf(InsufficientStockError);
  });
});
```

Integration tests use `testcontainers` (Node.js package) with real Postgres/Kafka. No mocking of infrastructure.

## Tooling

| Tool            | Purpose                              |
|-----------------|--------------------------------------|
| tsc             | type checking (noEmit in CI)         |
| eslint          | linting (typescript-eslint ruleset)  |
| prettier        | formatting                           |
| vitest or jest  | test runner                          |
| testcontainers  | integration test dependencies        |
| neverthrow      | Result type                          |

Run `tsc --noEmit`, `eslint`, and tests in CI on every push.
