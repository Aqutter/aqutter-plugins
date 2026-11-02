import { callPlugin } from '@aqutter/aqutter'
import type { PluginDefinition } from '@aqutter/aqutter'

/** 單一值的上限（UTF-8 位元組）。 */
export const MAX_VALUE_BYTES = 64 * 1024

export interface SecureStorageCapabilities {
  /** 此裝置能不能使用 `requireAuth`（有螢幕鎖定或生物辨識，且平台真的會強制驗證）。 */
  auth: boolean
  /** 此裝置有沒有登錄生物辨識。 */
  biometrics: boolean
}

/** 此 plugin 的契約：方法表。Dart 端 `SecureStoragePlugin` 必須提供同名方法（契約 rev 1）。 */
export type SecureStorageContract = PluginDefinition<
  {
    set: { req: { key: string, value: string, requireAuth?: boolean, prompt?: string }, res: Record<string, never> }
    get: { req: { key: string, prompt?: string }, res: { value: string | null } }
    has: { req: { key: string }, res: { exists: boolean } }
    delete: { req: { key: string }, res: Record<string, never> }
    keys: { req: Record<string, never>, res: { keys: string[] } }
    clear: { req: Record<string, never>, res: Record<string, never> }
    capabilities: { req: Record<string, never>, res: SecureStorageCapabilities }
  },
  Record<string, never>
>

// 把契約併入全域 plugin 表：使用端即可用 callPlugin('secure-storage', …) 得到完整型別
declare module '@aqutter/aqutter' {
  interface AqutterPluginRegistry {
    'secure-storage': SecureStorageContract
  }
}

/**
 * 網頁端 API。失敗時 `callPlugin` 拋出 `AqutterPluginError`，其 `code` 是契約的錯誤碼：
 * `invalid_key`、`too_large`、`auth_unavailable`、`auth_cancelled`、`auth_failed`、`key_invalidated`、`storage_error`。
 *
 * 值是字串；二進位資料請自行 base64。
 */
export const secureStorage = {
  /**
   * 存入一個項目；同名會取代（含條件）。
   * `requireAuth`：之後讀取要先通過生物辨識或裝置密碼。Android 上存入時也會出現驗證視窗。
   * 裝置沒有設定任何驗證方式時回 `auth_unavailable`，不會默默存成不需驗證。
   */
  set: async (key: string, value: string, options: { requireAuth?: boolean, prompt?: string } = {}): Promise<void> => {
    await callPlugin('secure-storage', 'set', { key, value, ...options })
  },
  /** 項目不存在回 null（不是錯誤）；需要驗證的項目會出現系統的驗證視窗，使用者取消回 `auth_cancelled`。 */
  get: async (key: string, options: { prompt?: string } = {}): Promise<string | null> =>
    (await callPlugin('secure-storage', 'get', { key, ...options })).value,
  /** 不會出現驗證視窗。 */
  has: async (key: string): Promise<boolean> => (await callPlugin('secure-storage', 'has', { key })).exists,
  /** 項目不存在也算成功；刪除不需要驗證。 */
  delete: async (key: string): Promise<void> => {
    await callPlugin('secure-storage', 'delete', { key })
  },
  /** 只列這個 plugin 寫的鍵，不含值，也不會出現驗證視窗。 */
  keys: async (): Promise<string[]> => (await callPlugin('secure-storage', 'keys', {})).keys,
  /** 只清這個 plugin 寫的項目。 */
  clear: async (): Promise<void> => {
    await callPlugin('secure-storage', 'clear', {})
  },
  capabilities: (): Promise<SecureStorageCapabilities> => callPlugin('secure-storage', 'capabilities', {}),
}
