import { NextResponse } from "next/server";
import { Ratelimit } from "@upstash/ratelimit";
import { Redis } from "@upstash/redis";

/**
 * Rate limiting implementation using Upstash Redis
 * Provides distributed rate limiting across serverless instances
 * Falls back to in-memory for local development
 */

const useRedis = !!(process.env.UPSTASH_REDIS_REST_URL && process.env.UPSTASH_REDIS_REST_TOKEN);

const redis = useRedis
  ? new Redis({
      url: process.env.UPSTASH_REDIS_REST_URL!,
      token: process.env.UPSTASH_REDIS_REST_TOKEN!,
    })
  : null;

// Upstash rate limiters (production)
const redisLimiters = redis
  ? {
      payment: new Ratelimit({ redis, limiter: Ratelimit.slidingWindow(10, "1 m"), prefix: "rl:payment" }),
      accountDelete: new Ratelimit({ redis, limiter: Ratelimit.slidingWindow(3, "1 h"), prefix: "rl:accountDelete" }),
      api: new Ratelimit({ redis, limiter: Ratelimit.slidingWindow(100, "1 m"), prefix: "rl:api" }),
      cron: new Ratelimit({ redis, limiter: Ratelimit.slidingWindow(5, "1 m"), prefix: "rl:cron" }),
      passwordReset: new Ratelimit({ redis, limiter: Ratelimit.slidingWindow(3, "1 h"), prefix: "rl:passwordReset" }),
      admin: new Ratelimit({ redis, limiter: Ratelimit.slidingWindow(30, "1 m"), prefix: "rl:admin" }),
    }
  : null;

// In-memory fallback for local development only
interface RateLimitEntry {
  count: number;
  resetTime: number;
}
const rateLimitStore = new Map<string, RateLimitEntry>();

// Cleanup expired entries every minute
if (!useRedis) {
  setInterval(() => {
    const now = Date.now();
    for (const [key, entry] of rateLimitStore.entries()) {
      if (entry.resetTime < now) {
        rateLimitStore.delete(key);
      }
    }
  }, 60000);
}

export const rateLimitConfigs = {
  payment: { limit: 10, windowMs: 60 * 1000 },
  accountDelete: { limit: 3, windowMs: 60 * 60 * 1000 },
  api: { limit: 100, windowMs: 60 * 1000 },
  cron: { limit: 5, windowMs: 60 * 1000 },
  passwordReset: { limit: 3, windowMs: 60 * 60 * 1000 },
  admin: { limit: 30, windowMs: 60 * 1000 },
};

export type RateLimitKey = keyof typeof rateLimitConfigs;

/**
 * Check rate limit for a given identifier and limit type
 * @param identifier - User ID or IP address
 * @param key - Type of rate limit to apply
 * @returns Object with success status, remaining requests, and reset time
 */
export async function checkRateLimit(
  identifier: string,
  key: RateLimitKey
): Promise<{ success: boolean; remaining: number; resetIn: number }> {
  const config = rateLimitConfigs[key];

  // Use Upstash Redis in production
  if (redisLimiters) {
    const limiter = redisLimiters[key];
    const result = await limiter.limit(identifier);
    return {
      success: result.success,
      remaining: result.remaining,
      resetIn: result.reset ? result.reset - Date.now() : config.windowMs,
    };
  }

  // In-memory fallback for local dev
  const now = Date.now();
  const entry = rateLimitStore.get(identifier);

  if (!entry || entry.resetTime < now) {
    rateLimitStore.set(identifier, {
      count: 1,
      resetTime: now + config.windowMs,
    });
    return { success: true, remaining: config.limit - 1, resetIn: config.windowMs };
  }

  if (entry.count >= config.limit) {
    return { success: false, remaining: 0, resetIn: entry.resetTime - now };
  }

  entry.count++;
  return { success: true, remaining: config.limit - entry.count, resetIn: entry.resetTime - now };
}

/**
 * Generate a rate limit error response
 * @param resetIn - Milliseconds until rate limit resets
 */
export function rateLimitResponse(resetIn: number) {
  return NextResponse.json(
    {
      error: "Too many requests",
      message: `Please try again in ${Math.ceil(resetIn / 1000)} seconds`,
    },
    {
      status: 429,
      headers: {
        "Retry-After": String(Math.ceil(resetIn / 1000)),
      },
    }
  );
}

/**
 * Get client identifier for rate limiting
 * Prefers user ID, falls back to IP address
 */
export function getClientIdentifier(request: Request, userId?: string): string {
  if (userId) {
    return `user:${userId}`;
  }
  const forwarded = request.headers.get("x-forwarded-for");
  const ip = forwarded ? forwarded.split(",")[0].trim() : "unknown";
  return `ip:${ip}`;
}
