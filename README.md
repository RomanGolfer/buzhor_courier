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
