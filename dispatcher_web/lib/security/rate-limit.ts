import { createHash } from "node:crypto";

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

const buckets = new Map<string, RateLimitBucket>();
let lastCleanupAt = 0;

export function checkRateLimit({
  key,
  limit,
  windowMs,
  now = Date.now()
}: RateLimitOptions) {
  cleanupExpiredBuckets(now);

  const existing = buckets.get(key);
  if (!existing || existing.resetAt <= now) {
    buckets.set(key, { count: 1, resetAt: now + windowMs });
    return {
      limited: false,
      remaining: Math.max(0, limit - 1),
      resetAt: now + windowMs,
      retryAfterSeconds: 0
    };
  }

  existing.count += 1;
  const retryAfterSeconds = Math.max(1, Math.ceil((existing.resetAt - now) / 1000));

  return {
    limited: existing.count > limit,
    remaining: Math.max(0, limit - existing.count),
    resetAt: existing.resetAt,
    retryAfterSeconds
  };
}

export function getClientIp(headers: HeaderReader) {
  return (
    headers.get("cf-connecting-ip")?.trim() ||
    headers.get("x-real-ip")?.trim() ||
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

function cleanupExpiredBuckets(now: number) {
  if (now - lastCleanupAt < 60_000) return;
  lastCleanupAt = now;

  for (const [key, bucket] of buckets.entries()) {
    if (bucket.resetAt <= now) {
      buckets.delete(key);
    }
  }
}
