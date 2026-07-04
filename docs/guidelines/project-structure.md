# Project Structure

Portainer Community Edition is a mixed Go and TypeScript application. The backend serves the API and embedded assets, while the frontend contains the legacy AngularJS application and the newer React code that is gradually replacing it.

## Top-Level Directories

- `api/` contains the Go server, HTTP handlers, persistence services, Docker and Kubernetes integrations, authentication, authorization, migrations, and runtime wiring.
- `pkg/` contains reusable Go packages that are not tied to one HTTP handler or storage implementation.
- `app/` contains the frontend application. It includes legacy AngularJS areas, React feature areas, shared React components, tests, assets, and frontend utilities.
- `build/`, `distribution/`, `package/`, and `webpack/` contain build, packaging, and bundling support.
- `translations/` contains i18n resources.
- `docs/` contains project documentation and contribution guidance.

## Frontend Layout

Use `app/react` for new React work unless an existing feature is still owned by AngularJS. Feature code usually lives under one of these domain folders:

- `app/react/portainer` for Portainer platform features such as users, teams, registries, settings, and environments.
- `app/react/docker` for Docker-specific views and API clients.
- `app/react/kubernetes` for Kubernetes-specific views, models, and API clients.
- `app/react/edge` for Edge and Edge Agent features.
- `app/react/azure` for Azure container instance features.
- `app/react/common` for shared domain features that are not generic UI primitives.
- `app/react/components` for reusable UI components.
- `app/react/hooks`, `app/react/utils`, and `app/react/test-utils` for shared hooks, utilities, and test helpers.

Keep feature-specific services, queries, hooks, components, and tests close to the feature. Move code into shared folders only when at least two real callers need it.

## Backend Layout

The backend is organized by responsibility:

- `api/cmd/portainer` wires the server executable.
- `api/http/handler` contains request handlers grouped by API area.
- `api/http/middlewares`, `api/http/security`, `api/http/errors`, and `api/http/utils` contain HTTP infrastructure.
- `api/dataservices` contains persistence-facing services for Portainer data models.
- `api/datastore` and `api/database` contain datastore setup, migrations, and low-level storage concerns.
- `api/docker`, `api/kubernetes`, `api/edge`, and related packages contain integration-specific behavior.
- `api/internal` contains backend code that should not be imported outside the backend module.
- `pkg/` is for stable reusable packages that are intentionally shared across backend areas.

Prefer adding code to the package that owns the behavior. Do not create new top-level packages for one handler or one helper.

## Common Development Tasks

- Run frontend type checks with `pnpm typecheck`.
- Run frontend tests with `pnpm test`.
- Run frontend linting with `pnpm lint`.
- Run backend tests with `go test ./...` or `make test-server`.
- Run full project checks with `make test` and `make lint` when the change has broad impact.

For small changes, run the narrowest command that proves the edited behavior works. For shared code, run the broader suite that covers its callers.

## Adding New Features

Start from the user-facing domain:

1. Add backend handlers, services, and data access in the relevant `api/` package.
2. Add or update generated API types only through the project generation flow.
3. Add frontend services and React Query hooks near the feature.
4. Add UI under the existing feature view hierarchy.
5. Add tests close to the code they verify.

Keep backend models, API payloads, frontend DTOs, and form models distinct when their responsibilities differ. Convert between them at boundaries.
