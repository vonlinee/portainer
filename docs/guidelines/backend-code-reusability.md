# Backend Code Reusability

Reusable backend code should have a clear owner, a narrow contract, and real callers. Avoid extracting helpers before the second use case proves the shape.

## When To Reuse

Create shared code when:

- Two or more packages need the same behavior.
- The behavior has a stable domain meaning.
- Sharing reduces duplicated validation, authorization, or integration logic.
- The shared API can be tested without pulling in unrelated dependencies.

Keep code local when it exists for one handler, one migration, or one integration edge case.

## Where Shared Code Belongs

- Use `pkg/` for reusable packages that are intentionally consumed across backend areas.
- Use `api/internal` for backend-only shared code that should not become a public package.
- Use the owning `api/<domain>` package when reuse is limited to that domain.
- Keep test-only helpers in test files or existing test helper packages.

Do not create generic `common` packages for unrelated helpers. Name packages after the capability they provide.

## CE And EE Boundaries

Community Edition code must remain useful without Enterprise Edition. When EE needs to extend CE behavior:

- Put the shared default behavior in CE.
- Add a small interface, strategy, or registration point only at the boundary that needs extension.
- Keep CE tests independent of EE packages.
- Avoid build tags or conditionals when a simple dependency inversion is enough.

The CE package should not import EE code or know EE implementation details.

## Abstraction Guidelines

Good shared code:

- Has a small public API.
- Names domain concepts explicitly.
- Accepts dependencies through parameters or constructors.
- Keeps side effects visible.
- Has tests for the shared contract.

Poor shared code:

- Takes broad service containers.
- Hides authorization or persistence side effects.
- Mixes unrelated helpers in one package.
- Forces callers to convert data into unnatural shapes.

Prefer duplication over a misleading abstraction. Duplication can be removed later; a bad abstraction spreads quickly.
