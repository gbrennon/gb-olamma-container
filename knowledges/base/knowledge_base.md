# Engineering Standards: Rust Architect (EDA + Hexagonal + TDD)

## 1. Architectural Core: Hexagonal (Ports & Adapters)
- **Domain Isolation:** The innermost layer must contain only pure business logic and entities. It must have zero dependencies on databases, frameworks, or external APIs.
- **Ports (Abstractions):** Use Rust traits to define interfaces for external communication (e.g., Repository, EventPublisher, ExternalService).
- **Adapters (Implementations):** Infrastructure-specific code (SQLx, Kafka, Redis) must live in the outer layer and implement the defined traits.
- **Dependency Inversion:** High-level domain modules must not depend on low-level infrastructure modules. Both must depend on abstractions (traits).

## 2. Rust Design Patterns & SOLID Principles
- **Value Objects over Primitive Obsession:** Never use raw types (String, i32) for domain concepts. Wrap them in struct or enum (NewType pattern) to enforce validation and type safety at the compiler level.
- **Composition over Inheritance:** Leverage the trait system and struct embedding to build complex behavior. Avoid deeply nested hierarchies; prefer small, focused traits.
- **Interface Segregation:** Keep traits small and specific. A consumer should not be forced to depend on methods it does not use.
- **Single Responsibility (SRP):** Each module or struct must have one reason to change. Separate command handling from query logic.
- **Dependency Injection:** Use trait objects or generics with trait bounds to inject dependencies into domain services at runtime.

## 3. Event-Driven Architecture (EDA)
- **High-Throughput Design:** Prioritize asynchronous, non-blocking execution using the tokio runtime.
- **Decoupling:** Services communicate via events. The producer of an event must have no knowledge of the consumers.
- **Resilience Patterns:** Implement Idempotency Keys to handle duplicate messages. Use the Outbox Pattern to ensure atomicity between database updates and event publishing.
- **Failure Handling:** Design for eventual consistency. Always include logic for retries with exponential backoff and Dead Letter Queues (DLQ).

## 4. Test-Driven Development (TDD) Workflow
The model must strictly adhere to the Red-Green-Refactor cycle:
1. **Red:** Write a failing unit test that defines the desired behavior for a small piece of logic.
2. **Green:** Write the minimal amount of Rust code necessary to make the test pass.
3. **Refactor:** Clean up the code, remove duplication, and ensure adherence to SOLID principles while keeping tests passing.
- **Testing Strategy:** Use mockall or manual trait implementations for mocking ports during unit tests. Focus on behavior-driven assertions.

## 5. Engineering Excellence & Code Smells
- **Zero-Unwrap Policy:** Never use .unwrap() or .expect() in production-ready code. Use Result and Option with proper error propagation (anyhow/thiserror).
- **Avoid God Objects:** Break down large structs and "Manager" classes into smaller, composable units.
- **Clean API Surfaces:** Keep module visibility (pub, pub(crate)) as restrictive as possible to prevent leaking implementation details.
- **Performance:** Avoid unnecessary allocations and prefer borrowing over cloning where ownership rules allow.:
