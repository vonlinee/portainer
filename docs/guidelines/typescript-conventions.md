# TypeScript Conventions

Use TypeScript to make data boundaries explicit and to prevent invalid UI states. Prefer clear domain names and narrow types over broad reusable shapes.

## Types

- Prefer `type` aliases for object shapes and unions unless an existing nearby file uses interfaces.
- Export types only when another module needs them.
- Keep API response types, form value types, and component prop types separate when they represent different concepts.
- Use generated API types where available instead of duplicating backend contracts.
- Avoid `any`. Use `unknown` at trust boundaries and narrow it before use.

Use optional properties only when the value may truly be absent. If a value is required but may be empty, model that explicitly.

## Union Types

Prefer discriminated unions for state that has modes:

```ts
type LoadState =
  | { type: 'loading' }
  | { type: 'ready'; items: Item[] }
  | { type: 'error'; message: string };
```

Avoid boolean combinations such as `isLoading`, `isReady`, and `hasError` when only one state can be valid at a time.

## Constants And Enums

- Prefer named constants for repeated literals.
- Prefer string literal unions for small frontend-only option sets.
- Use enums only when matching an existing API contract or local convention.
- Keep constants close to the feature unless they are intentionally shared.

## Functions

- Keep function inputs explicit.
- Return typed results from exported functions.
- Avoid hidden mutation of arguments.
- Prefer early returns for validation and guard clauses.
- Keep async functions responsible for one level of work: fetching, transforming, or coordinating.

## React Props

- Name prop types after the component, for example `UserSelectorProps`.
- Keep component props minimal and purposeful.
- Pass callbacks with domain names such as `onUserSelect` or `onEnvironmentRemove`.
- Avoid passing whole resource objects into generic components when only an ID and name are needed.

## Anti-Patterns

Avoid:

- `any` to silence compiler errors.
- Large shared utility types that hide the real model.
- Type assertions where validation or narrowing would be safer.
- Boolean flags that create invalid combinations.
- Re-export barrels that make ownership unclear.
- Duplicating generated API types by hand.

When a type is awkward, first check whether the data boundary is doing too much.
