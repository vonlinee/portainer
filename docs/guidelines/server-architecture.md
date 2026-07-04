# Server Architecture

The Portainer server is organized around HTTP handlers, domain services, datastore access, and integration clients. Keep dependencies flowing from entry points toward lower-level capabilities, and keep business decisions out of transport glue.

## Layers

- HTTP handlers parse requests, enforce request-level authorization, call services, and write responses.
- Services coordinate domain behavior, validation, datastore access, and integration calls.
- Dataservices and repositories persist Portainer models.
- Integration packages call Docker, Kubernetes, Git, registry, Edge, and other external systems.
- Shared packages in `pkg/` provide reusable infrastructure or domain logic with stable boundaries.

Do not put business workflows directly in HTTP request parsing code when the behavior needs to be reused or tested independently.

## Handlers

Handlers should:

- Decode and validate request input.
- Read identity, endpoint, and authorization context.
- Call one or more service methods.
- Map service results to response payloads.
- Convert errors to the appropriate HTTP status.

Keep handlers thin enough that the same behavior could be exercised from tests without an HTTP router when needed.

## Services

Services should:

- Own domain decisions.
- Make transaction boundaries explicit when the datastore supports them.
- Keep external API calls visible and injectable where tests need control.
- Return meaningful errors that handlers can classify.
- Avoid depending on frontend-specific request shapes.

If a service starts mixing unrelated workflows, split it by domain behavior instead of by technical helper type.

## Transactions And Consistency

When a workflow writes multiple related records, define where the transaction starts and ends. Keep side effects such as external API calls, filesystem writes, and event emission outside datastore transactions when possible, or document why they must be inside.

For update flows, be explicit about read-modify-write behavior and conflict handling.

## CE And EE Sharing

Community Edition code should not depend on Enterprise Edition packages. Shared behavior should live in CE-accessible packages with extension points that EE can use without changing CE ownership rules.

Prefer small interfaces or hooks at the boundary where EE needs to extend behavior. Keep CE defaults complete and testable on their own.

## API Contracts

Keep API request and response structs close to the handler package that owns the route. Do not expose datastore models directly when the API contract differs from persistence.

When changing an API contract, update generated frontend types, tests, and any OpenAPI definitions required by the existing workflow.
