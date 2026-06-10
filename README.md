# Buzhor Courier

Buzhor Courier is the production repository for the Buzhor delivery workflow.
It contains the Flutter courier app, the Next.js dispatcher panel, Supabase
database migrations, and the Supabase Edge Function used for courier push
notifications.

## Current Stack

- Flutter mobile app for Android and iOS.
- Next.js 16 dispatcher web panel deployed on Vercel.
- Supabase Auth, Postgres, RLS, Realtime, and Edge Functions.
- Firebase Cloud Messaging for courier order notifications.
- Upstash Redis or Vercel KV for production dispatcher rate limiting.
- Nominatim geocoding through the dispatcher web API route.

Deployment is Vercel-based; no alternative platform deployment config is
tracked in this repository.

## Repository Layout

```text
lib/                         Flutter courier app
assets/                      Mobile app images and logos
android/, ios/               Native mobile project files
test/                        Flutter unit and widget tests
dispatcher_web/              Next.js dispatcher/admin panel
supabase/migrations/         Supabase schema, RLS, functions, and triggers
supabase/functions/          Supabase Edge Functions
docs/                        Design and backend sync notes
.github/workflows/           CI, CodeQL, and secret scanning
```

`docs/backend_sync_architecture.md` started as design notes for the backend
sync model. The implemented system now lives in Supabase migrations, Flutter
repositories/providers, and the dispatcher web app.

## Access Model

The mobile app requires:

- a valid Supabase Auth user;
- an active row in `public.profiles`;
- `profiles.role` of `courier`, `dispatcher`, or `admin`;
- an active `public.couriers` row linked by `couriers.profile_id`.

The dispatcher web panel requires an active `dispatcher` or `admin` profile.
Database access must remain enforced by Supabase RLS and constraints, not only
by UI checks.

## Local Prerequisites

- Flutter stable with Dart 3.11-compatible SDK.
- Xcode and CocoaPods for iOS builds.
- Node.js 20 for the dispatcher web app.
- Deno 2 for Supabase Edge Function checks.
- Supabase CLI for linked project operations and production key lookup.
- `jq` for the release build helper commands below.

Install dependencies:

```sh
flutter pub get
cd dispatcher_web
npm ci
cd ..
```

For iOS after dependency changes:

```sh
cd ios
pod install
cd ..
```

## Supabase Configuration

Default project URL:

```text
https://txzzkrqekynqansqvnbj.supabase.co
```

The Flutter app supports both:

- `SUPABASE_PUBLISHABLE_KEY`
- `SUPABASE_ANON_KEY`

Current release builds should use the legacy JWT `anon` key through
`SUPABASE_ANON_KEY`. The code still supports publishable keys, but mobile
release REST/auth behavior has been validated with the legacy anon key.

Get the anon key from an authenticated Supabase CLI session without printing it:

```sh
legacy_anon=$(
  supabase projects api-keys --project-ref txzzkrqekynqansqvnbj -o json \
    | jq -r '.[] | select(.name == "anon") | .api_key // .key // .value'
)
```

Run the courier app against Supabase:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://txzzkrqekynqansqvnbj.supabase.co \
  --dart-define=SUPABASE_ANON_KEY="$legacy_anon"
```

Without Supabase credentials, debug builds can still use the local demo auth
path. Release builds require a backend key.

Never expose `SUPABASE_SERVICE_ROLE_KEY` in Flutter or browser code. See
`SECURITY.md` before changing auth, RLS, secrets, CSP, rate limiting, or
deployment configuration.

## Mobile Builds

Android release APK:

```sh
legacy_anon=$(
  supabase projects api-keys --project-ref txzzkrqekynqansqvnbj -o json \
    | jq -r '.[] | select(.name == "anon") | .api_key // .key // .value'
)

flutter build apk --release \
  --dart-define=SUPABASE_URL=https://txzzkrqekynqansqvnbj.supabase.co \
  --dart-define=SUPABASE_ANON_KEY="$legacy_anon"
```

Install the latest Android release build on a connected device:

```sh
flutter install -d <android-device-id> --release
```

iOS release app:

```sh
legacy_anon=$(
  supabase projects api-keys --project-ref txzzkrqekynqansqvnbj -o json \
    | jq -r '.[] | select(.name == "anon") | .api_key // .key // .value'
)

flutter build ios --release \
  --dart-define=SUPABASE_URL=https://txzzkrqekynqansqvnbj.supabase.co \
  --dart-define=SUPABASE_ANON_KEY="$legacy_anon"
```

Install on a connected iPhone:

```sh
flutter install -d <ios-device-id> --release --device-timeout=90
```

If iOS installs but refuses to launch, trust the developer profile on the
iPhone in Settings before opening the app.

## Dispatcher Web

The dispatcher app lives in `dispatcher_web/` and is deployed on Vercel.

Required `.env.local` values:

```sh
NEXT_PUBLIC_SUPABASE_URL=https://txzzkrqekynqansqvnbj.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_publishable_or_anon_key
```

Production geocoding requires a real contact identity:

```sh
NOMINATIM_USER_AGENT="buzhor-dispatcher/1.0 (https://your-domain.example; ops@your-domain.example)"
```

Production rate limiting should use Upstash Redis or Vercel KV:

```sh
UPSTASH_REDIS_REST_URL=...
UPSTASH_REDIS_REST_TOKEN=...

# or Vercel KV integration values
KV_REST_API_URL=...
KV_REST_API_TOKEN=...
```

Dispatcher commands:

```sh
cd dispatcher_web
npm run dev
npm run lint
npm run typecheck
npm run build
```

The root `package.json` also proxies production build/start commands into
`dispatcher_web/` for deployment environments that use the repository root.

## Supabase Edge Function

`supabase/functions/send-order-push` sends FCM notifications for assigned
orders. It requires these Supabase/Firebase secrets in the Supabase project:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
FIREBASE_SERVICE_ACCOUNT_JSON
FIREBASE_PROJECT_ID
```

Validate the function locally:

```sh
cd supabase/functions/send-order-push
deno fmt --check index.ts
deno check index.ts
cd ../../..
```

Deploy after reviewing the target project:

```sh
supabase functions deploy send-order-push --project-ref txzzkrqekynqansqvnbj
```

## Validation

Before committing production changes, run the relevant checks:

```sh
dart analyze
flutter test
```

For dispatcher web changes:

```sh
cd dispatcher_web
npm run lint
npm run typecheck
npm run build
cd ..
```

For Edge Function changes:

```sh
cd supabase/functions/send-order-push
deno fmt --check index.ts
deno check index.ts
cd ../../..
```

CI runs Flutter analysis/tests, dispatcher web audit/typecheck, Supabase Edge
Function checks, CodeQL, and Gitleaks.

## Production Notes

- Supabase migrations are in `supabase/migrations/`; review linked project
  drift before pushing migrations.
- Dispatcher web production is Vercel-based.
- Mobile release artifacts are not committed.
- Keep generated folders such as `build/`, `.dart_tool/`, `.next/`, and
  `node_modules/` out of commits.
- Store production secrets only in Supabase, Vercel, GitHub Actions, or the
  relevant platform dashboard.
