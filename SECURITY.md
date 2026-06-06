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
- Dispatcher web uses authenticated Supabase sessions, role checks, CSP, anti-clickjacking headers, and rate limiting on sensitive endpoints.
- Supabase access must be enforced by RLS policies and database constraints, not by client UI checks alone.

## Required Environment Variables

The dispatcher web app requires these public Supabase values at build/runtime:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY
```

These are publishable browser values, not service-role secrets. Never expose `SUPABASE_SERVICE_ROLE_KEY` in the Flutter app or dispatcher web client.

## Automated Checks

- Flutter CI runs dependency install, static analysis, and tests.
- Dispatcher web CI runs `npm audit --omit=dev` and TypeScript checks.
- CodeQL scans JavaScript/TypeScript code.
- Dependabot monitors Flutter Pub, npm, and GitHub Actions dependencies.

## Reporting

For now, report security issues directly to the repository owner. Include the affected area, reproduction steps, and whether any user data or credentials may be exposed.
