/**
 * 应用版本信息
 * 版本号由 vite.config.ts 从 package.json 注入，无需手动维护
 */
declare const __APP_VERSION__: string

export const APP_VERSION = __APP_VERSION__

/**
 * 获取版本显示文本
 */
export function getVersionText(): string {
  return `v${APP_VERSION}`
}
