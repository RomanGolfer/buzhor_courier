# Buzhor Dispatcher Web

Next.js 16 dispatcher panel for Buzhor Courier.

## Environment

Create `.env.local`. These variables are required; the app does not ship with a
fallback Supabase key.

```sh
NEXT_PUBLIC_SUPABASE_URL=https://txzzkrqekynqansqvnbj.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_publishable_or_anon_key
SUPABASE_SERVICE_ROLE_KEY=server_only_service_role_key
```

For production geocoding, also set a real Nominatim contact identity:

```sh
NOMINATIM_USER_AGENT="buzhor-dispatcher/1.0 (https://your-domain.example; ops@your-domain.example)"
```

For PBX/ATS integration, configure the server-only telephony variables:

```sh
TELEPHONY_PROVIDER=generic
TELEPHONY_ORIGINATE_URL=https://pbx.example.com/api/originate
TELEPHONY_API_TOKEN=server_only_pbx_token
TELEPHONY_FROM_EXTENSION=100
TELEPHONY_WEBHOOK_SECRET=shared_webhook_secret
```

The dispatcher calls `POST /api/telephony/call`; the server forwards the call to
`TELEPHONY_ORIGINATE_URL` with `{ to, from_extension, order_id,
dispatcher_profile_id }`.

Configure the PBX to send call status webhooks to `POST /api/telephony/webhook`
with `Authorization: Bearer <TELEPHONY_WEBHOOK_SECRET>` or
`x-telephony-secret`. Supported payload fields include `event_type`,
`direction`, `phone`, `provider_call_id`, `order_id`, `started_at`,
`answered_at`, `ended_at`, `duration_seconds`, and `recording_url`.

Production rate limiting should use durable Upstash Redis storage:

```sh
UPSTASH_REDIS_REST_URL=...
UPSTASH_REDIS_REST_TOKEN=...
```

When Upstash is connected through Vercel KV, the app also accepts Vercel's
generated `KV_REST_API_URL` and `KV_REST_API_TOKEN` variables.

HSTS is enabled in production with `max-age=31536000`. Enable subdomains and
preload only after the final domain and every subdomain are permanently HTTPS:

```sh
ENABLE_HSTS_SUBDOMAINS=true
ENABLE_HSTS_PRELOAD=true
```

## Commands

```sh
npm install
npm run dev
npm run typecheck
npm run build
```

The panel requires a Supabase user whose `profiles.role` is `dispatcher` or `admin`.
