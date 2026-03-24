# Software Architecture: Hexagonal and EDA

## Hexagonal Architecture (Ports and Adapters)
- Domain Isolation: The core domain must contain business logic and entities only.
- Ports: Define all external interactions (DB, Messaging, API) as Rust traits.
- Adapters: Infrastructure implementations must exist in separate modules and implement domain traits.
- Dependency Inversion: The domain must not depend on external libraries (SQLx, Kafka).

## Event-Driven Architecture (EDA)
- Decoupling: Producers must not know about consumers.
- Resilience: Implement Idempotency Keys for all event consumers.
- Atomicity: Use the Outbox Pattern for database-to-event consistency.
- Fault Tolerance: Design for eventual consistency with retries and Dead Letter Queues (DLQ).
