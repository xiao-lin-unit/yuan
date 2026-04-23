import dayjs from 'dayjs'

/**
 * Timezone utility - All times are in UTC+8 (China Standard Time)
 */

/**
 * Get current date/time in UTC+8
 */
export function getCurrentDate(): dayjs.Dayjs {
  return dayjs().add(8, 'hour')
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
export function toUTC8ISOString(date: dayjs.Dayjs | string | Date): string {
  return dayjs(date as any).add(8, 'hour').toISOString()
}

/**
 * Get current timestamp in milliseconds (UTC+8)
 */
export function getCurrentTimestamp(): number {
  return dayjs().valueOf() + (8 * 60 * 60 * 1000)
}

/**
 * Format date for database storage (UTC+8)
 */
export function formatForDB(date: dayjs.Dayjs | string | Date = dayjs()): string {
  return dayjs(date as any).add(8, 'hour').toISOString()
}

/**
 * Create a new dayjs object representing current UTC+8 time
 * This is a drop-in replacement for new Date()
 */
export function createDate(): dayjs.Dayjs {
  return getCurrentDate()
}

/**
 * Get Date.now() equivalent for UTC+8
 */
export function dateNow(): number {
  return getCurrentTimestamp()
}
