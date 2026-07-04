# Frontend Conventions

Portainer frontend code is split between legacy AngularJS and newer React. Use React and TypeScript for new UI work unless the change must live inside an existing AngularJS feature.

## Component Structure

- Keep feature components inside the owning feature folder under `app/react`.
- Use `app/react/components` for reusable UI primitives and shared application components.
- Prefer small components that own one rendering concern.
- Keep data fetching, permission checks, and form state outside low-level visual components.
- Co-locate tests with the component or utility they cover.

Use existing components before introducing new ones. Tables, buttons, form controls, modals, badges, loaders, tooltips, and empty states usually already have shared implementations.

## Data Fetching

Use React Query for server state:

- Put API calls in feature `services` files.
- Put query and mutation hooks in feature `queries` files or folders.
- Use stable query keys with enough scope to avoid collisions.
- Invalidate or update affected queries after mutations.
- Keep request and response mapping near the service boundary.

Do not store server state in local component state unless it is derived view state. Local state is appropriate for open panels, selected rows, filters, wizard steps, and form drafts.

## Forms

- Use the form libraries and helper components already used by the surrounding feature.
- Keep validation rules close to the form model.
- Prefer explicit submit payload construction over passing raw form state to API calls.
- Show field-level errors where possible and preserve existing API error handling patterns.
- Disable submit actions while the request is in progress.

When a form edits a backend resource, keep separate types for the resource, the form values, and the API payload if their shapes differ.

## Styling And UI

- Prefer shared Portainer components and Tailwind utility classes already present in nearby code.
- Keep visual changes consistent with the surrounding screen.
- Avoid one-off CSS when a shared component or utility class can express the intent.
- Use accessible labels, button text, and semantic elements.
- Preserve keyboard interaction for modals, menus, forms, and tables.

Avoid large layout rewrites when changing one workflow. Keep UI changes scoped to the feature request.

## Error And Loading States

Every async view should handle:

- Initial loading.
- Empty data.
- API errors.
- Permission or feature flag restrictions when applicable.
- Mutating or saving state.

Use existing notification and error display helpers rather than inventing new message patterns.

## Feature Boundaries

Feature folders may contain components, services, queries, models, and utilities for that feature. Shared code should move upward only when reuse is real and the abstraction name is domain-neutral.

Avoid importing from another feature's internal folder. If two features need the same code, move the shared part into `app/react/common`, `app/react/components`, `app/react/hooks`, or `app/react/utils`, depending on what it does.
