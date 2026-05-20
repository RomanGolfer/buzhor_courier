# buzhor_courier

Buzhor Courier is a Flutter courier app for delivery execution, route work,
payment handoff, and local-first order handling.

## Architecture

- [Backend and sync architecture](docs/backend_sync_architecture.md)

## Validation

Before committing production changes, run:

```sh
dart analyze
flutter test
flutter build apk --debug
```

## Supabase

The app can run without Supabase credentials in local demo mode. To enable the
backend login/config path, pass a publishable client key at build or run time:

```sh
flutter run --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
```

The default project URL is `https://txzzkrqekynqansqvnbj.supabase.co`. Override
it only when pointing the app to another Supabase project:

```sh
flutter run --dart-define=SUPABASE_URL=https://project-ref.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
```
