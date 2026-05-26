const fallbackSupabaseUrl = "https://txzzkrqekynqansqvnbj.supabase.co";
const fallbackSupabaseAnonKey =
  "sb_publishable_4EUQnEl_Qv5jlSrMEgWqjQ_-Jk6oGVa";

export function getSupabaseConfig() {
  return {
    url: process.env.NEXT_PUBLIC_SUPABASE_URL || fallbackSupabaseUrl,
    anonKey:
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || fallbackSupabaseAnonKey,
  };
}
