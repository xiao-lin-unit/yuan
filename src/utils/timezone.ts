import dayjs from 'dayjs'
import utc from 'dayjs/plugin/utc'
import timezone from 'dayjs/plugin/timezone'

dayjs.extend(utc)
dayjs.extend(timezone)

// 设置默认东八区
dayjs.tz.setDefault('Asia/Shanghai')
/**
 * Timezone utility - All times are in UTC+8 (China Standard Time)
 */

/**
 * Get current date/time in UTC+8
 */
export function getCurrentDate(): dayjs.Dayjs {
  return dayjs().tz()
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
  return dayjs(date as any).tz().toISOString()
}

/**
 * Get current timestamp in milliseconds (UTC+8)
 */
export function getCurrentTimestamp(): number {
  return getCurrentDate().valueOf()
}

/**
 * Format date for database storage (UTC+8)
 */
export function formatForDB(date: dayjs.Dayjs | string | Date = dayjs()): string {
  return dayjs(date as any).tz().toISOString()
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

export function getDate(date: dayjs.Dayjs | string | Date): dayjs.Dayjs {
  return dayjs(date as any).tz()
}

export function formatDate(date: dayjs.Dayjs | string | Date, format: string = 'YYYY-MM-DD HH:mm:ss'): string {
  if (!date) return '-'
  return getDate(date).format(format)
}
