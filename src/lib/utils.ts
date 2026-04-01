import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

/**
 * Utility functions for SitEasy
 */

/**
 * Merge Tailwind CSS classes with proper precedence
 */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

/**
 * Get today's date in YYYY-MM-DD format for South Africa timezone
 * Critical for booking date comparisons
 */
export function getTodaySA(): string {
  return new Date().toLocaleDateString("en-CA", {
    timeZone: "Africa/Johannesburg",
  });
}

/**
 * Parse a date string to local midnight
 * Prevents timezone-related bugs with date-only strings
 */
export function parseLocalDate(dateString: string): Date {
  return new Date(dateString + "T00:00:00");
}

/**
 * Parse a date string to end of day (23:59:59)
 */
export function parseLocalDateEnd(dateString: string): Date {
  return new Date(dateString + "T23:59:59");
}

/**
 * Format currency in South African Rand
 */
export function formatCurrency(cents: number): string {
  const rand = cents / 100;
  return new Intl.NumberFormat("en-ZA", {
    style: "currency",
    currency: "ZAR",
  }).format(rand);
}

/**
 * Calculate number of days between two dates
 */
export function daysBetween(startDate: string, endDate: string): number {
  const start = parseLocalDate(startDate);
  const end = parseLocalDate(endDate);
  const diffTime = Math.abs(end.getTime() - start.getTime());
  return Math.ceil(diffTime / (1000 * 60 * 60 * 24));
}

/**
 * Format relative time (e.g., "2 hours ago")
 */
export function formatRelativeTime(date: Date | string): string {
  const now = new Date();
  const then = typeof date === "string" ? new Date(date) : date;
  const diffMs = now.getTime() - then.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);

  if (diffMins < 1) return "just now";
  if (diffMins < 60) return `${diffMins} minute${diffMins > 1 ? "s" : ""} ago`;
  if (diffHours < 24) return `${diffHours} hour${diffHours > 1 ? "s" : ""} ago`;
  if (diffDays < 7) return `${diffDays} day${diffDays > 1 ? "s" : ""} ago`;
  
  return then.toLocaleDateString("en-ZA");
}

/**
 * Truncate text with ellipsis
 */
export function truncate(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  return text.slice(0, maxLength - 3) + "...";
}

/**
 * Generate initials from name
 */
export function getInitials(firstName?: string, lastName?: string): string {
  if (!firstName && !lastName) return "?";
  const first = firstName?.charAt(0).toUpperCase() || "";
  const last = lastName?.charAt(0).toUpperCase() || "";
  return first + last;
}

/**
 * Validate South African phone number format
 */
export function isValidSAPhone(phone: string): boolean {
  // Accepts: +27, 0, or direct 10-digit
  const cleaned = phone.replace(/\s/g, "");
  return /^(\+27|0)[6-8][0-9]{8}$/.test(cleaned);
}

/**
 * Format South African phone number
 */
export function formatSAPhone(phone: string): string {
  const cleaned = phone.replace(/\s/g, "");
  if (cleaned.startsWith("+27")) {
    return cleaned.replace(/(\+27)(\d{2})(\d{3})(\d{4})/, "$1 $2 $3 $4");
  }
  if (cleaned.startsWith("0")) {
    return cleaned.replace(/(\d{3})(\d{3})(\d{4})/, "$1 $2 $3");
  }
  return phone;
}

/**
 * Sleep utility for testing/delays
 */
export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
