# Production Phone Auth Plan

When Buzhor Courier moves toward real production rollout, add phone-based
authentication for couriers in Russia.

Preferred approach:

- Keep Supabase Auth as the source of sessions and `auth.uid()`.
- Enable Supabase phone auth / phone OTP.
- Add a Supabase Send SMS Hook. Supabase currently lists this hook as available
  on Free and Pro projects.
- Send OTP codes through a Russian SMS provider such as SMSC.ru, SMS Aero, or
  another provider chosen during rollout.
- Keep email/password available as a fallback, especially for dispatcher/admin
  users.
- Ensure courier login phone numbers match `profiles.phone` / `couriers.phone`
  and continue to rely on existing RLS policies after authentication.

Reason:

- Supabase native SMS providers may not be reliable or practical for Russian
  phone numbers.
- A Send SMS Hook lets Supabase generate and verify OTP codes while our backend
  controls the regional SMS delivery channel.
- This avoids building a custom auth system and preserves existing Supabase RLS,
  profile, courier, and order access logic.

Before implementation:

- Pick and create an account with the SMS provider.
- Confirm pricing, sender name requirements, and delivery rules for Russian
  operators.
- Store provider credentials only in Supabase secrets.
- Add abuse/rate-limit monitoring for OTP requests.
- Configure CAPTCHA / rate limits for OTP requests before opening public signup.
- Test the full flow with a real Russian number before replacing the current
  internal email/password courier login.

Current Supabase limitation:

- "Prevent use of leaked passwords" is available only on Supabase Pro and above.
  On the current Free project this security advisor warning cannot be fully
  resolved without upgrading the project.
