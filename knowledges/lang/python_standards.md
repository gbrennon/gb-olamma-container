# Python Standards

## Project Layout

```
src/
  domain/          # pure business logic, no external imports
  application/     # use cases, orchestration, port interfaces (ABC/Protocol)
  infrastructure/  # adapters: SQLAlchemy, httpx, kafka, etc.
  main.py          # composition root
tests/
  unit/            # domain + application, all ports mocked
  integration/     # infrastructure adapters, real dependencies
```

## Type Annotations

Enforce `mypy --strict` in CI. No `Any` in domain or application layers.

```python
# NewType for domain identifiers
from typing import NewType
from uuid import UUID

OrderId = NewType("OrderId", UUID)
CustomerId = NewType("CustomerId", UUID)
```

## Value Objects via Dataclass

```python
from dataclasses import dataclass
from decimal import Decimal

@dataclass(frozen=True)
class Amount:
    value: Decimal

    def __post_init__(self) -> None:
        if self.value <= 0:
            raise ValueError(f"Amount must be positive, got {self.value}")
```

Use `frozen=True` on all domain value objects. Mutability is a bug in the domain layer.

## Port Definition

Prefer `Protocol` over `ABC` for ports — no forced inheritance on adapters:

```python
from typing import Protocol

class OrderRepository(Protocol):
    async def save(self, order: Order) -> None: ...
    async def find_by_id(self, order_id: OrderId) -> Order | None: ...
```

Use `ABC` only when you need to share default behavior across implementations.

## Error Handling

```python
# Typed domain error hierarchy
class DomainError(Exception):
    pass

class InsufficientStockError(DomainError):
    def __init__(self, requested: int, available: int) -> None:
        self.requested = requested
        self.available = available
        super().__init__(f"Requested {requested}, available {available}")
```

Never use bare `except:`. Never catch `Exception` in domain logic.
Log errors at the adapter boundary only, not inside domain or application code.

## Async

```python
# Use asyncio.TaskGroup for structured concurrency (Python 3.11+)
async def process_batch(items: list[Item]) -> list[Result]:
    async with asyncio.TaskGroup() as tg:
        tasks = [tg.create_task(process(item)) for item in items]
    return [t.result() for t in tasks]
```

Never mix sync and async code in the same call chain silently.
Use `asyncio.to_thread` for blocking I/O inside async contexts.

## Testing

```python
# Unit test — mock the port, not the implementation
@pytest.fixture
def mock_repo() -> OrderRepository:
    return MagicMock(spec=OrderRepository)

async def test_should_raise_when_stock_is_zero(mock_repo: OrderRepository) -> None:
    mock_repo.find_stock.return_value = 0
    service = OrderService(repository=mock_repo)
    with pytest.raises(InsufficientStockError):
        await service.place_order(order_id, quantity=1)
```

Integration tests use `testcontainers` (Python package). No mocking of Postgres, Redis, or Kafka in integration tests.

## Tooling

| Tool       | Purpose                        |
|------------|-------------------------------|
| mypy       | static type checking (strict) |
| ruff       | linting + formatting          |
| pytest     | test runner                   |
| pytest-asyncio | async test support        |
| testcontainers | integration test deps     |

Run `mypy`, `ruff check`, and `pytest` in CI on every push.
