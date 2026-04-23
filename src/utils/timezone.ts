/**
 * Timezone utility - All times are in UTC+8 (China Standard Time)
 */

/**
 * Get current date/time in UTC+8
 */
export function getCurrentDate(): Date {
  const now = new Date()
  // Convert to UTC+8
  const utc8Time = new Date(now.getTime() + (8 * 60 * 60 * 1000))
  return utc8Time
}

/**
 * Get current ISO string in UTC+8
 */
export function getCurrentISOString(): string {
  return getCurrentDate().toISOString()
}

/**
 * Convert a date to UTC+8 ISO string
 */
export function toUTC8ISOString(date: Date | string): string {
  const d = typeof date === 'string' ? new Date(date) : date
  const utc8Time = new Date(d.getTime() + (8 * 60 * 60 * 1000))
  return utc8Time.toISOString()
}

/**
 * Get current timestamp in milliseconds (UTC+8)
 */
export function getCurrentTimestamp(): number {
  return Date.now() + (8 * 60 * 60 * 1000)
}

/**
 * Format date for database storage (UTC+8)
 */
export function formatForDB(date: Date | string = new Date()): string {
  const d = typeof date === 'string' ? new Date(date) : date
  const utc8Time = new Date(d.getTime() + (8 * 60 * 60 * 1000))
  return utc8Time.toISOString()
}

/**
 * Create a new Date object representing current UTC+8 time
 * This is a drop-in replacement for new Date()
 */
export function createDate(): Date {
  return getCurrentDate()
}

/**
 * Get Date.now() equivalent for UTC+8
 */
export function dateNow(): number {
  return getCurrentTimestamp()
}
