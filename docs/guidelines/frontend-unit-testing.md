# Frontend Unit Testing

Frontend tests use Vitest and React Testing Library. Tests should describe user-visible behavior and important data transformations, not implementation details.

## Test Location

- Place component tests next to the component as `ComponentName.test.tsx`.
- Place utility and service tests next to the file as `name.test.ts`.
- Use `app/react/test-utils` for shared rendering helpers and providers.
- Keep mocks close to the test unless they are shared across many tests.

## Component Tests

Prefer tests that interact with the UI the way a user would:

- Query by role, label, text, or display value.
- Use `userEvent` for user interaction.
- Assert visible outcomes, submitted payloads, disabled states, and error messages.
- Wrap components in the same providers they need in production.

Avoid testing private component state, CSS class names, or implementation-specific DOM structure unless the structure is the behavior.

## Data Fetching Tests

For React Query code:

- Use a fresh query client per test.
- Seed query data when the component behavior does not depend on the fetch itself.
- Mock service functions at the service boundary.
- Assert invalidation or mutation side effects when they are part of the contract.

Do not share a query client across tests. Cache leakage makes tests order-dependent.

## Async Behavior

- Await user interactions when they trigger asynchronous work.
- Use `findBy...` queries for elements that appear later.
- Use `waitFor` for side effects that do not directly render an element.
- Assert loading and disabled states when they protect important workflows.

## What To Cover

Add or update tests for:

- New conditional rendering.
- Permission and feature flag behavior.
- Form validation and submit payloads.
- Error handling paths.
- Query and mutation behavior.
- Utility functions with non-trivial branching.

Small visual-only changes may not need new tests if existing coverage already exercises the component.

## Test Quality

Keep tests readable. Arrange data with small factory helpers when setup is noisy, but avoid hiding the behavior being tested. One strong behavior test is better than several brittle implementation tests.
