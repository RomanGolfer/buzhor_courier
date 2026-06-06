# Security Policy

## Production Baseline

- Keep GitHub 2FA enabled for every maintainer with repository access.
- Protect the `main` branch and require CI checks before merge.
- Store production secrets only in the deployment platform or Supabase dashboard.
- Do not commit `.env`, `.env.local`, signing certificates, private keys, or access tokens.
- Rotate any token that was pasted into chat, logs, screenshots, or terminal history.

## Application Controls

- Mobile order cache and sync journals are stored through platform secure storage.
- Android backup is disabled and cleartext traffic is blocked.
- iOS App Transport Security blocks arbitrary network loads.
- Dispatcher web uses authenticated Supabase sessions, role (`dispatcher`/`admin`) and `is_active` checks on every request.
- Rate limiting on login (8 req / 10 min) and geocode (30 req / min) endpoints; backed by Upstash Redis in production, in-memory fallback for local dev only.
- **HSTS** (`max-age=63072000; includeSubDomains; preload`) is set in production to enforce HTTPS.
- **Content-Security-Policy** is generated per-request in middleware with a cryptographic nonce; `script-src` uses `'nonce-<n>' 'strict-dynamic'` in production (no `unsafe-inline`).
- Static security headers on all responses: `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, `Permissions-Policy`.
- Login error messages are intentionally generic to prevent user-enumeration attacks.
- Nominatim geocoding requests include a policy-compliant `User-Agent` with contact information.
- Supabase access must be enforced by RLS policies and database constraints, not by client UI checks alone.
- Input length and coordinate range constraints on `profiles`, `couriers`, and `orders` are fully validated (VALIDATE CONSTRAINT applied).

## Required Environment Variables

The dispatcher web app requires these public Supabase values at build/runtime:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY
```

Optional — enables durable rate limiting (required in production):

```text
UPSTASH_REDIS_REST_URL
UPSTASH_REDIS_REST_TOKEN
```

These are publishable browser values, not service-role secrets. Never expose `SUPABASE_SERVICE_ROLE_KEY` in the Flutter app or dispatcher web client.

## Automated Checks

- Flutter CI runs dependency install, static analysis, and tests.
- Dispatcher web CI runs `npm audit --omit=dev` and TypeScript checks.
- CodeQL scans JavaScript/TypeScript code.
- Gitleaks scans commits for accidentally committed secrets.
- GitHub Actions secret-scan workflow runs on every push.
- Dependabot monitors Flutter Pub, npm, and GitHub Actions dependencies.

## Reporting

For now, report security issues directly to the repository owner. Include the affected area, reproduction steps, and whether any user data or credentials may be exposed.
