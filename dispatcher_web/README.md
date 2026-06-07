# Buzhor Dispatcher Web

Next.js 16 dispatcher panel for Buzhor Courier.

## Environment

Create `.env.local`. These variables are required; the app does not ship with a
fallback Supabase key.

```sh
NEXT_PUBLIC_SUPABASE_URL=https://txzzkrqekynqansqvnbj.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_publishable_or_anon_key
```

For production geocoding, also set a real Nominatim contact identity:

```sh
NOMINATIM_USER_AGENT="buzhor-dispatcher/1.0 (https://your-domain.example; ops@your-domain.example)"
```

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
