/** @type {import('next').NextConfig} */
const nextConfig = {
  typedRoutes: true,
  env: {
    NEXT_PUBLIC_SUPABASE_URL:
      process.env.NEXT_PUBLIC_SUPABASE_URL ||
      "https://txzzkrqekynqansqvnbj.supabase.co",
    NEXT_PUBLIC_SUPABASE_ANON_KEY:
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||
      "sb_publishable_4EUQnEl_Qv5jlSrMEgWqjQ_-Jk6oGVa",
  },
};

export default nextConfig;
