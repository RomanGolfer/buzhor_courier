import { createHash } from "node:crypto";
import { Ratelimit } from "@upstash/ratelimit";
import { Redis } from "@upstash/redis";

type HeaderReader = Pick<Headers, "get">;

type RateLimitBucket = {
  count: number;
  resetAt: number;
};

type RateLimitOptions = {
  key: string;
  limit: number;
  windowMs: number;
  now?: number;
};

export type RateLimitResult = {
  limited: boolean;
  remaining: number;
  resetAt: number;
  retryAfterSeconds: number;
};

// ─── Upstash setup ───────────────────────────────────────────────────────────
// Instantiated lazily; null when UPSTASH_REDIS_REST_URL/TOKEN are absent.

let upstashRedis: Redis | null = null;
let inMemoryWarningLogged = false;
const rlCache = new Map<string, Ratelimit>();

function getRedis(): Redis | null {
  if (upstashRedis !== null) return upstashRedis;

  const url = process.env.UPSTASH_REDIS_REST_URL ?? process.env.KV_REST_API_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN ?? process.env.KV_REST_API_TOKEN;

  if (url && token) {
    upstashRedis = new Redis({ url, token });
    return upstashRedis;
  }

  if (!inMemoryWarningLogged) {
    inMemoryWarningLogged = true;
    console.warn(
      "[rate-limit] UPSTASH_REDIS_REST_URL/TOKEN not configured — " +
        "or Vercel KV_REST_API_URL/TOKEN not available — " +
        "falling back to in-memory rate limiting. " +
        "State resets on cold starts; not suitable for production."
    );
  }
  return null;
}

function getUpstashRatelimit(redis: Redis, limit: number, windowMs: number): Ratelimit {
  const cacheKey = `${limit}:${windowMs}`;
  const cached = rlCache.get(cacheKey);
  if (cached) return cached;

  const rl = new Ratelimit({
    redis,
    limiter: Ratelimit.slidingWindow(limit, msToDuration(windowMs)),
    analytics: false,
  });
  rlCache.set(cacheKey, rl);
  return rl;
}

// Convert milliseconds to the nearest human-readable Upstash Duration unit.
function msToDuration(ms: number): `${number} ${"ms" | "s" | "m" | "h" | "d"}` {
  if (ms % 86_400_000 === 0) return `${ms / 86_400_000} d`;
  if (ms % 3_600_000 === 0) return `${ms / 3_600_000} h`;
  if (ms % 60_000 === 0) return `${ms / 60_000} m`;
  if (ms % 1_000 === 0) return `${ms / 1_000} s`;
  return `${ms} ms`;
}

// ─── In-memory fallback (single-instance / local dev only) ───────────────────

const buckets = new Map<string, RateLimitBucket>();
let lastCleanupAt = 0;

function checkRateLimitInMemory({
  key,
  limit,
  windowMs,
  now = Date.now(),
}: RateLimitOptions): RateLimitResult {
  cleanupExpiredBuckets(now);

  const existing = buckets.get(key);
  if (!existing || existing.resetAt <= now) {
    buckets.set(key, { count: 1, resetAt: now + windowMs });
    return {
      limited: false,
      remaining: Math.max(0, limit - 1),
      resetAt: now + windowMs,
      retryAfterSeconds: 0,
    };
  }

  existing.count += 1;
  const retryAfterSeconds = Math.max(1, Math.ceil((existing.resetAt - now) / 1000));

  return {
    limited: existing.count > limit,
    remaining: Math.max(0, limit - existing.count),
    resetAt: existing.resetAt,
    retryAfterSeconds,
  };
}

function cleanupExpiredBuckets(now: number) {
  if (now - lastCleanupAt < 60_000) return;
  lastCleanupAt = now;
  for (const [key, bucket] of buckets.entries()) {
    if (bucket.resetAt <= now) buckets.delete(key);
  }
}

// ─── Public API ───────────────────────────────────────────────────────────────

export async function checkRateLimit({
  key,
  limit,
  windowMs,
  now = Date.now(),
}: RateLimitOptions): Promise<RateLimitResult> {
  const redis = getRedis();

  if (redis) {
    const rl = getUpstashRatelimit(redis, limit, windowMs);
    const result = await rl.limit(key);
    const retryAfterSeconds = result.success
      ? 0
      : Math.max(1, Math.ceil((result.reset - Date.now()) / 1000));
    return {
      limited: !result.success,
      remaining: result.remaining,
      resetAt: result.reset,
      retryAfterSeconds,
    };
  }

  return checkRateLimitInMemory({ key, limit, windowMs, now });
}

// On Vercel, x-real-ip is set by the platform and is the authoritative client IP.
// cf-connecting-ip is set by Cloudflare when it sits in front of Vercel.
// x-forwarded-for is only trusted when the deployment sits behind a known reverse proxy.
export function getClientIp(headers: HeaderReader) {
  return (
    headers.get("x-real-ip")?.trim() ||
    headers.get("cf-connecting-ip")?.trim() ||
    headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    "unknown"
  );
}

export function rateLimitKey(scope: string, headers: HeaderReader, subject = "") {
  const ipHash = hashRateLimitPart(getClientIp(headers));
  const subjectHash = subject ? hashRateLimitPart(subject.toLowerCase()) : "none";
  return `${scope}:${ipHash}:${subjectHash}`;
}

function hashRateLimitPart(value: string) {
  return createHash("sha256").update(value).digest("hex").slice(0, 32);
}
