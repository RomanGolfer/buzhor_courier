# Backend and Sync Architecture

This document describes the target backend/sync contour for Buzhor Courier before implementation starts. The current app is a local-first Flutter prototype: orders are cached on the device, a local action journal exists, push notifications and payment checks are placeholders, and authentication is not connected to a server yet.

## Goals

- Keep the courier app usable on weak mobile networks, VPN issues, and short offline windows.
- Make the backend the source of truth for orders, couriers, prices, payments, and dispatcher decisions.
- Preserve courier actions locally until the server acknowledges them.
- Give dispatchers a bot/admin surface for assigning orders and tracking execution.
- Avoid silent data loss when the app is killed, reinstalled, or a request fails halfway.

## Non-Goals for the First Backend Pass

- Full route optimization as a backend product. Routing can stay app-side at first, then move to a route provider/table service later.
- Real-time collaboration between many dispatchers. Start with a single dispatcher flow and audit trail.
- Payment provider settlement logic. The first pass only needs payment intent/status integration boundaries.

## Actors

- Courier: uses the Flutter app, sees assigned orders, scans bottles, marks orders delivered or failed, sends payment QR to the client.
- Dispatcher: assigns orders, updates order details, sees courier progress, receives exceptions, and can contact courier/client.
- Backend API: authenticates users, stores order state, accepts courier actions, serves current configuration.
- Dispatcher bot: Telegram or another messenger bot used by the dispatcher for quick order creation, assignment, and alerts.
- Payment provider: later replaces the current placeholder payment status service.

## Core Order States

The app currently has `active`, `delivered`, and `failed`. The backend should use a more explicit lifecycle while mapping cleanly to the current UI:

| Backend state | App mapping | Meaning |
| --- | --- | --- |
| `draft` | hidden | Dispatcher is preparing the order. |
| `assigned` | `active` | Order is assigned to a courier and visible in the app. |
| `accepted` | `active` | Courier device has received the order. |
| `in_progress` | `active` | Courier started route or opened/scanned the order. |
| `delivered_pending_sync` | local only | Courier completed delivery offline, not acknowledged yet. |
| `delivered` | `delivered` | Server accepted completion. |
| `failed_pending_sync` | local only | Courier failed delivery offline, not acknowledged yet. |
| `failed` | `failed` | Server accepted failure reason. |
| `cancelled` | hidden or read-only | Dispatcher cancelled the order before completion. |

Local pending states do not need to become public backend states. They can live in the app sync queue and UI badges.

## Order Identity

Use separate identity fields:

- `id`: stable backend identifier, UUID or numeric database id. No `#` prefix.
- `orderNumber`: human-readable display number, for example `#4821`.
- `version`: monotonic integer or revision token used for conflict detection.
- `updatedAt`: server timestamp for sorting and audit display.

The app can keep showing `#4821`, but API paths and sync entries should use `id`.

## Courier Operations

These are the first server-backed operations the app should support:

| Operation | Current local analog | Required payload |
| --- | --- | --- |
| `orders.fetchAssigned` | `fetchOrders` | courier id, cursor/version, device id |
| `orders.acknowledgeReceipt` | none | order ids, local received timestamp |
| `orders.complete` | `OrderActionType.complete` | order id, version, delivered bottles, returned bottles, extras, scanned items, confirmed payment, comment, client-local timestamp, idempotency key |
| `orders.fail` | `OrderActionType.fail` | order id, version, reason, comment, client-local timestamp, idempotency key |
| `orders.upsertFromDispatcher` | `OrderActionType.upsert` | full order snapshot from backend/push |
| `payments.createQr` | `_paymentQrPayload` placeholder | order id, amount, payment method |
| `payments.checkStatus` | `PaymentStatusService.checkPayment` placeholder | payment id or order id |
| `config.fetch` | hardcoded constants | prices, dispatcher contact, feature flags, route provider settings |

Every courier mutation must be idempotent. The client should generate an `operationId` once, store it in the queue, and retry with the same id until the backend returns a terminal result.

## Local Sync Queue

The existing `OrderActionJournalEntry` should evolve from a replay-after-crash journal into a durable sync queue.

Target fields:

- `operationId`: UUID generated on the device.
- `type`: `complete`, `fail`, `acknowledgeReceipt`, `paymentCheck`, or future operations.
- `orderId`: backend id.
- `orderVersion`: version seen by the courier when the action was made.
- `createdAtLocal`: device timestamp.
- `payload`: operation-specific data.
- `status`: `pending`, `inFlight`, `acked`, `rejected`, `needsReview`.
- `attemptCount`: retry count.
- `nextAttemptAt`: exponential backoff scheduling.
- `lastError`: last transport/server error for diagnostics.

Queue rules:

- Append the operation before mutating visible local order state.
- Apply optimistic local state immediately for courier UX.
- Never clear the queue until the backend acknowledges the specific `operationId`.
- Retry transport failures automatically with backoff.
- Treat validation/conflict failures as `needsReview`, not silent success.
- Keep an audit record of acked operations for support/debugging, even if the active queue is compacted.

## Conflict Rules

Use optimistic concurrency with `orderVersion`.

Recommended first-pass behavior:

- If the courier completes an order and the backend still has the same version, accept and increment version.
- If dispatcher edited address/items before completion, backend returns `409 conflict` with latest order snapshot.
- If the order was cancelled before completion, mark local action as `needsReview` and show a clear dispatcher-contact state.
- If the same `operationId` is submitted twice, return the original result.
- If two different terminal actions arrive for the same order, the backend accepts the first valid terminal action and rejects the later one with latest state.

For the courier UI, conflicts should be rare and explicit. Do not hide them under generic snackbars.

## Backend Data Model

Minimum tables/collections:

- `users`: courier/dispatcher accounts, auth provider id, role, status.
- `couriers`: courier profile, phone, active device id, region.
- `devices`: push token, platform, app version, last seen.
- `orders`: customer, address, coordinates, items, prices, payment method, lifecycle state, assigned courier, version.
- `order_events`: append-only audit trail of dispatcher and courier actions.
- `sync_operations`: idempotency records keyed by `operationId`.
- `payments`: QR/payment provider ids, amount, status, status timestamps.
- `config_versions`: prices, dispatcher contacts, route provider config, feature flags.

The `orders` row is the current read model. `order_events` and `sync_operations` are the source for audits and support.

## API Shape

Start with a small REST API. WebSockets can wait until push and polling prove insufficient.

Suggested endpoints:

```text
POST /auth/login
POST /auth/refresh
GET  /courier/config
GET  /courier/orders?sinceVersion=...
POST /courier/orders/{id}/ack
POST /courier/orders/{id}/complete
POST /courier/orders/{id}/fail
POST /courier/sync
POST /payments/qr
GET  /payments/{id}/status
```

`POST /courier/sync` can accept a batch of queued operations and return per-operation results:

```json
{
  "results": [
    {
      "operationId": "uuid",
      "status": "acked",
      "serverVersion": 42,
      "order": {}
    }
  ],
  "serverTime": "2026-05-20T00:00:00Z"
}
```

## Authentication

Replace the current login delay with real auth:

- Phone/password or one-time code for couriers.
- Dispatcher/admin accounts with stronger access control.
- Short-lived access token plus refresh token.
- Store tokens in secure storage, not SharedPreferences.
- Bind push token and device id after login.
- Support forced logout when a courier account is disabled.

The app should not show assigned orders until auth succeeds or a valid cached session is restored.

## Push and Polling

Push should wake the app and hint what changed, but the backend remains authoritative.

Push event examples:

- `orders.assigned`
- `orders.updated`
- `orders.cancelled`
- `payments.statusChanged`
- `config.updated`

After receiving a push, the app fetches the latest snapshot/delta from the API. If push is unavailable, periodic polling on app foreground and route screen refresh is enough for the first production pass.

## Dispatcher Bot

The bot should be a dispatcher tool, not a hidden backend.

First bot commands/actions:

- Create order from structured text or form.
- Assign order to courier.
- Reassign or cancel order.
- Show courier route/progress summary.
- Alert when a courier action is stuck in `needsReview`.
- Send payment/check status summary.

The bot must write through the same backend API/domain layer as the admin panel. It should not directly edit client caches.

## Configuration from Server

Move these hardcoded values behind `config.fetch` before production:

- Dispatcher phone.
- Water and extras pricing.
- Payment QR provider parameters.
- Route/geocoding provider endpoints and keys.
- Low-data feature flags and polling intervals.
- Time slot definitions.

The app should cache the latest config and include a `configVersion` in diagnostics.

## Implementation Phases

1. Define API DTOs and backend order ids while keeping current local UI behavior.
2. Replace local action journal clearing with durable pending/acked queue semantics.
3. Add auth and secure token storage.
4. Add backend order fetch and config fetch behind repository interfaces.
5. Add sync worker for queued courier operations with idempotency.
6. Add dispatcher bot/admin path for order creation and assignment.
7. Connect push notifications and payment status provider.
8. Move routing/geocoding endpoints to config or backend-owned provider.

## Open Decisions

- Backend stack: Supabase, custom API, Firebase, or another managed backend.
- Dispatcher bot platform and whether an admin web panel is also needed.
- Payment provider and QR format.
- Source of geocoding/routing in production.
- Exact order id format and migration from current display-style ids.
- How much historical audit data must be visible to dispatchers.

## First Coding Tasks After This Design

- Introduce backend-safe `OrderItem.id` and separate display `orderNumber`.
- Convert `OrderActionJournalEntry` into a persistent sync operation model.
- Add repository interfaces for `OrderApiClient`, `ConfigApiClient`, and `AuthRepository`.
- Replace hardcoded dispatcher phone and pricing with cached server config defaults.
- Add tests for queued operation retry, idempotency, and conflict handling.
