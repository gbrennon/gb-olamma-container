# Skills

Reusable prompt fragments for use with aider, opencode, cline, and similar tools.

## What belongs here

A skill is a focused, self-contained prompt that instructs a coding assistant to apply a specific
pattern or technique. Skills are loaded on demand — you include them in a session when the task
requires that pattern. They are not loaded by default.

Skills complement the model's built-in system prompt (from prompts/). The system prompt defines
the engineering identity and invariants. Skills provide step-by-step scaffolding for specific tasks.

## Usage

With aider, load a skill by reading it into context:

```zsh
aider-rust --read skills/hexagonal-scaffold.md src/domain/order.rs
```

With opencode or cline, paste the skill content into the chat before describing the task.

## Naming Convention

kebab-case filenames. One pattern or technique per file. Keep files under 80 lines.

## Index

| File                    | Purpose                                              |
|-------------------------|------------------------------------------------------|
| hexagonal-scaffold.md   | Scaffold a new hexagonal slice (port + adapter + app service) |
| tdd-cycle.md            | Step-by-step TDD prompting for a single unit         |
| outbox-pattern.md       | Implement the transactional outbox pattern           |
| value-object.md         | Generate a validated value object / newtype          |
