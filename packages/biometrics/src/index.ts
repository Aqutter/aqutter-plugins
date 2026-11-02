import { callPlugin } from '@aqutter/aqutter'
import type { PluginDefinition } from '@aqutter/aqutter'

/** 平台能回報的生物辨識種類；可能為空。 */
export type BiometricType = 'fingerprint' | 'face' | 'iris' | 'strong' | 'weak'

/**
 * 驗證的結果。取消、失敗、被鎖定、裝置不可用都是正常結果，不是錯誤。
 *
 * - `authenticated`：使用者通過驗證。
 * - `cancelled`：使用者取消，或系統中斷了視窗。
 * - `failed`：驗證沒有通過（辨識不符），可重試。
 * - `locked_out`：嘗試太多次，暫時鎖定。
 * - `permanently_locked_out`：生物辨識被鎖住，需要使用者以裝置密碼解鎖。
 * - `unavailable`：裝置沒有可用的驗證方式（或 `biometricOnly` 但沒有生物辨識），這個平台也可能根本沒有驗證功能。
 * - `busy`：已經有一個驗證視窗在進行中。
 */
export type AuthStatus =
  | 'authenticated'
  | 'cancelled'
  | 'failed'
  | 'locked_out'
  | 'permanently_locked_out'
  | 'unavailable'
  | 'busy'

export interface BiometricCapabilities {
  /** 裝置有可用的驗證方式（生物辨識或裝置密碼／螢幕鎖定）。 */
  available: boolean
  /** 裝置已登錄生物辨識（不含只有裝置密碼）。 */
  biometrics: boolean
  types: BiometricType[]
}

export interface AuthenticateOptions {
  /** 驗證視窗顯示的說明文字，必填，1 到 100 字。plugin 不解讀它，也不知道你在保護什麼。 */
  reason: string
  /** 視窗標題，≤ 60 字；只有 Android 使用。 */
  title?: string
  /** 取消按鈕文字，≤ 30 字；Android 與 iOS 使用。 */
  cancelLabel?: string
  /** 預設 `false`：沒登錄生物辨識的使用者仍可用裝置密碼。`true` 時只接受生物辨識。 */
  biometricOnly?: boolean
}

/** 此 plugin 的契約：方法表。Dart 端 `BiometricsPlugin` 必須提供同名方法（契約 rev 1）。 */
export type BiometricsContract = PluginDefinition<
  {
    capabilities: { req: Record<string, never>, res: BiometricCapabilities }
    authenticate: { req: AuthenticateOptions, res: { status: AuthStatus } }
  },
  Record<string, never>
>

// 把契約併入全域 plugin 表：使用端即可用 callPlugin('biometrics', …) 得到完整型別
declare module '@aqutter/aqutter' {
  interface AqutterPluginRegistry {
    biometrics: BiometricsContract
  }
}

/**
 * 網頁端 API。任何時候都能呼叫，沒有前置條件，也不快取「剛驗證過」：每次都會出現系統的驗證視窗。
 *
 * **plugin 在這個平台用不了時不拋錯**（`callPlugin` 回 `undefined`）：`authenticate` 回 `{ status: 'unavailable' }`，
 * `capabilities` 回「都沒有」。
 *
 * 注意：結果只是這個裝置上、此刻的客戶端判斷，**不能當成伺服器端的憑證**（網頁端的結果可以被改寫）。
 * 要保護機密請用 `secure-storage` 的 `requireAuth`。
 */
export const biometrics = {
  capabilities: async (): Promise<BiometricCapabilities> =>
    (await callPlugin('biometrics', 'capabilities', {})) ?? { available: false, biometrics: false, types: [] },
  /** 叫起系統的驗證視窗，回傳結果狀態；只有參數不合法才會拋 `invalid_argument`。 */
  authenticate: async (options: AuthenticateOptions): Promise<AuthStatus> =>
    (await callPlugin('biometrics', 'authenticate', options))?.status ?? 'unavailable',
}
