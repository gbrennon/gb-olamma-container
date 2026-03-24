# Scala Standards

## Effect System

Pick one effect type per project and never mix them: ZIO, cats-effect IO, or (legacy only) Future.
Use ZIO environment (ZLayer) or Reader/Kleisli for dependency injection rather than a DI framework.
Prefer ZIO for new projects: typed error channel (ZIO[R, E, A]) eliminates unchecked exceptions at the type level.

## Value Objects and Domain Modeling

```scala
// Newtype via opaque type (Scala 3) — zero runtime overhead
opaque type OrderId = UUID
object OrderId:
  def apply(value: UUID): OrderId = value
  extension (id: OrderId) def value: UUID = id

// Smart constructor returning Either for validated types
final case class Amount private (value: BigDecimal)
object Amount:
  def of(value: BigDecimal): Either[DomainError, Amount] =
    if value > 0 then Right(Amount(value))
    else Left(DomainError.InvalidAmount(value))
```

## Port Definition (Tagless Final)

```scala
trait OrderRepository[F[_]]:
  def save(order: Order): F[Unit]
  def findById(id: OrderId): F[Option[Order]]

// ZIO style port
trait OrderRepository:
  def save(order: Order): IO[RepositoryError, Unit]
  def findById(id: OrderId): IO[RepositoryError, Option[Order]]
```

## Error Modeling

```scala
sealed trait DomainError extends Throwable
object DomainError:
  final case class InsufficientStock(requested: Int, available: Int) extends DomainError
  final case class InvalidAmount(value: BigDecimal)                  extends DomainError
  case object OrderAlreadyConfirmed                                  extends DomainError
```

Never throw inside domain logic. Return `Either[DomainError, A]` or use the ZIO error channel.

## Testing

Unit tests: ZIO Test or MUnit. Mock ports with manual in-memory implementations, not mockito.
Integration tests: testcontainers-scala with real Postgres/Kafka. No mocking of infrastructure.

```scala
// ZIO Test example
suite("OrderService")(
  test("should return InsufficientStock when quantity exceeds available") {
    for
      repo    <- InMemoryOrderRepository.make
      service  = OrderService(repo)
      result  <- service.place(order).flip
    yield assertTrue(result.isInstanceOf[DomainError.InsufficientStock])
  }
)
```

## Build Tool

Use sbt or Mill. Separate source sets per layer: `domain`, `application`, `infrastructure`, `main`.
Enforce layer boundaries with `dependsOn` declarations — `domain` must have zero infrastructure dependencies.
