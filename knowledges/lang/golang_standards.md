# Go Standards

## Project Layout

```
internal/
  domain/          # entities, value objects, domain errors, port interfaces
  application/     # use cases — depend only on domain interfaces
  infrastructure/  # adapters: postgres, kafka, http clients
cmd/
  api/main.go      # composition root, wires everything together
tests/
  unit/            # domain + application with fakes
  integration/     # infrastructure adapters with real dependencies
```

`internal/` enforces Go's package visibility rules across the module boundary.
`domain/` must import nothing outside the standard library.

## Named Types for Domain Identifiers

```go
type OrderID    string
type CustomerID string
type Amount     int64  // store in minor units (cents), never float

func NewOrderID(raw string) (OrderID, error) {
    if raw == "" {
        return "", errors.New("order id must not be empty")
    }
    return OrderID(raw), nil
}
```

## Value Objects with Validation

```go
type Amount struct{ value int64 }

func NewAmount(value int64) (Amount, error) {
    if value <= 0 {
        return Amount{}, fmt.Errorf("amount must be positive, got %d", value)
    }
    return Amount{value: value}, nil
}

func (a Amount) Value() int64 { return a.value }
```

Unexported fields enforce construction through the validated constructor.

## Port Definition

```go
// domain/ports/order_repository.go
// Define interfaces at the point of use, not implementation.
type OrderRepository interface {
    Save(ctx context.Context, order Order) error
    FindByID(ctx context.Context, id OrderID) (*Order, error)
}
```

Interfaces live in `domain/` or alongside the application code that consumes them, never in `infrastructure/`.

## Error Handling

```go
// domain/errors.go
var (
    ErrInsufficientStock = errors.New("insufficient stock")
    ErrOrderNotFound     = errors.New("order not found")
)

type InsufficientStockError struct {
    Requested int
    Available int
}

func (e *InsufficientStockError) Error() string {
    return fmt.Sprintf("requested %d, available %d", e.Requested, e.Available)
}

func (e *InsufficientStockError) Is(target error) bool {
    return target == ErrInsufficientStock
}
```

Always check errors. Never use `_` to discard an error in production code.
Wrap with context: `fmt.Errorf("placing order: %w", err)`.
Unwrap with `errors.Is` and `errors.As`.

## Context Propagation

`context.Context` is the first parameter of every function that crosses a boundary (repository, HTTP, messaging).
Never store context in a struct. Always pass it explicitly.
Always respect context cancellation in loops and blocking calls.

## Concurrency

```go
// Use errgroup for structured goroutine lifecycle
g, ctx := errgroup.WithContext(ctx)

g.Go(func() error { return processOrders(ctx) })
g.Go(func() error { return publishEvents(ctx) })

if err := g.Wait(); err != nil {
    return fmt.Errorf("batch processing: %w", err)
}
```

## Testing

Prefer fakes (in-memory implementations) over mocks for ports:

```go
// tests/fakes/order_repository.go
type InMemoryOrderRepository struct {
    mu     sync.RWMutex
    orders map[OrderID]Order
}

func (r *InMemoryOrderRepository) Save(_ context.Context, order Order) error {
    r.mu.Lock()
    defer r.mu.Unlock()
    r.orders[order.ID] = order
    return nil
}
```

Use table-driven tests for behavior coverage:

```go
func TestOrderService_PlaceOrder(t *testing.T) {
    tests := []struct {
        name      string
        stock     int
        quantity  int
        wantErr   error
    }{
        {"should succeed when stock is sufficient", 10, 5, nil},
        {"should fail when stock is zero",           0, 1, ErrInsufficientStock},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) { /* ... */ })
    }
}
```

Integration tests use `testcontainers-go`. No mocking of Postgres, Kafka, or Redis.

## Tooling

| Tool              | Purpose                          |
|-------------------|----------------------------------|
| go vet            | static analysis                  |
| staticcheck       | extended static analysis         |
| golangci-lint     | linting (configured via .golangci.yml) |
| go test -race     | race condition detection         |
| testcontainers-go | integration test dependencies    |

Run `go vet`, `staticcheck`, `golangci-lint run`, and `go test -race ./...` in CI on every push.
