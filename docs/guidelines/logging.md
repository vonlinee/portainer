# Logging

Portainer backend logging should help operators understand what happened without exposing secrets or creating noisy output. Follow the existing zerolog-based patterns in the surrounding package.

## Log Levels

- `Debug` is for diagnostic details useful during development or deep troubleshooting.
- `Info` is for important lifecycle events and meaningful user or system actions.
- `Warn` is for recoverable problems that may need operator attention.
- `Error` is for failed operations that the system could not complete.

Do not log expected validation failures as errors. Return them to the caller and let the handler choose the response.

## Message Style

- Use concise, action-oriented messages.
- Include enough structured fields to identify the resource, endpoint, user, or integration involved.
- Keep messages stable so they can be searched in logs.
- Avoid punctuation-heavy or multi-sentence log messages.

Prefer structured fields over string interpolation.

## Sensitive Data

Never log:

- Passwords, tokens, API keys, JWTs, OAuth secrets, or private keys.
- Full authorization headers.
- Kubeconfig contents or registry credentials.
- Raw request bodies that may contain secrets.

When a value is useful for troubleshooting but sensitive, log a safe identifier, resource ID, endpoint ID, username, or truncated hash instead.

## Errors

Attach errors with the existing zerolog error pattern used in the package. Add context with structured fields rather than duplicating the whole error message in the log text.

If an error is returned to a caller and logged by a higher layer, avoid logging it again at every lower layer. Duplicate logs make one failure look like many.

## Where To Log

Log at boundaries:

- Server startup and shutdown.
- External API calls that fail in operationally meaningful ways.
- Background jobs and scheduled work.
- Security-relevant decisions.
- Unexpected datastore or integration failures.

Avoid logs inside tight loops unless they are debug-level and clearly bounded.
