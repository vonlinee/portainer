# Go Conventions

Backend code should be simple, explicit, and easy to test. Follow the style of the surrounding package before introducing a new pattern.

## Naming

- Use short names for local variables when the scope is small.
- Use descriptive names for exported types, services, and interfaces.
- Keep package names lowercase and focused on one responsibility.
- Avoid package names such as `common`, `helpers`, or `utils` for new backend packages unless the existing package already owns that concern.

Export only what other packages need.

## Error Handling

- Return errors instead of panicking.
- Add context when returning an error across a boundary.
- Preserve sentinel or typed errors when callers need to branch on them.
- Convert backend errors to HTTP responses at the handler boundary.
- Keep log messages and returned errors separate when they serve different audiences.

Prefer early returns for validation and failure paths.

## Context

- Accept `context.Context` in functions that perform I/O, call external services, or may block.
- Pass the request context from handlers into services.
- Do not store contexts in structs.
- Respect cancellation when calling Docker, Kubernetes, datastore, or network APIs.

## Interfaces

Define interfaces at the consumer side when they make testing or substitution clearer. Avoid interfaces with only one implementation unless they mark a real boundary.

Keep interfaces small. A handler usually needs a focused service method, not an entire datastore surface.

## Tests

- Prefer table-driven tests for validation and branching logic.
- Use focused test fixtures and avoid global mutable state.
- Add tests near the package under test.
- Use `pkg/testhelpers` and existing helpers when they fit.
- Test handler behavior at the HTTP boundary when status codes, payloads, or authorization behavior matter.

Run `go test ./...` for broad backend changes. For narrow changes, run the affected package tests first.

## Code Style

- Keep functions small enough to read without jumping between distant blocks.
- Group related validation together.
- Avoid hidden side effects in helper functions.
- Prefer standard library functionality unless the project already uses a dependency for the same job.
- Let `gofmt` and `go test` be the baseline before review.
