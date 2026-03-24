# Test-Driven Development (TDD) Workflow

## The Cycle
1. Red: Write a failing unit test first. This defines the requirement and the API interface.
2. Green: Write the minimum amount of code to make the test pass. Do not over-engineer here.
3. Refactor: Improve the code structure while keeping the tests green. Ensure adherence to SOLID.

## Testing Standards
- Use mockall or manual trait mocks for infrastructure adapters during unit tests.
- Tests must be deterministic and descriptive.
- All code must be validated by the TDD process before being finalized.
