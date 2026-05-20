# Buzhor Dispatcher Web

Next.js 14 dispatcher panel for Buzhor Courier.

## Environment

Create `.env.local`:

```sh
NEXT_PUBLIC_SUPABASE_URL=https://txzzkrqekynqansqvnbj.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_publishable_or_anon_key
```

## Commands

```sh
npm install
npm run dev
npm run typecheck
npm run build
```

The panel requires a Supabase user whose `profiles.role` is `dispatcher` or `admin`.
