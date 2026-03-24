# Rust Implementation Standards

## Type Safety and Patterns
- Avoid Primitive Obsession: Use the NewType pattern and Value Objects for domain concepts (e.g., OrderId, Amount).
- Composition over Inheritance: Use traits and struct embedding for shared behavior.
- Use explicit visibility (pub, pub(crate)) to protect implementation details.

## Error Handling and Performance
- Zero-Unwrap Policy: No .unwrap() or .expect() in production code.
- Use anyhow for application logic and thiserror for domain/library errors.
- Minimize allocations and prefer borrowing over cloning.

## Concurrency
- Primary Runtime: tokio.
- Ensure all shared state is protected by Thread-safe primitives where necessary, but prioritize message passing.
