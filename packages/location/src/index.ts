import { callPlugin, onPluginEvent } from '@aqutter/aqutter'
import type { PluginDefinition } from '@aqutter/aqutter'

/** 沿用殼的權限狀態字串。 */
export type PermissionStatus = 'granted' | 'denied' | 'permanentlyDenied' | 'restricted' | 'limited' | 'prompt'

/** 精度三檔：`high`（預設，最佳）、`balanced`（中等）、`low`（省電）。 */
export type LocationAccuracy = 'high' | 'balanced' | 'low'

/**
 * 一個位置。經緯度為度；`accuracy`、`altitudeAccuracy` 為公尺；`heading` 為度（0 到 360）；`speed` 為公尺／秒；
 * `timestamp` 為 Unix 毫秒。平台沒有的欄位省略。
 */
export interface Position {
  latitude: number
  longitude: number
  accuracy: number
  timestamp: number
  altitude?: number
  altitudeAccuracy?: number
  heading?: number
  speed?: number
  isMocked?: boolean
}

export interface LocationCapabilities {
  /** 系統的定位服務是否開著。 */
  serviceEnabled: boolean
  permission: PermissionStatus
}

export interface CurrentPositionOptions {
  /** 預設 `high`。 */
  accuracy?: LocationAccuracy
  /** 1,000 到 60,000，預設 15,000。 */
  timeoutMs?: number
}

export interface WatchOptions {
  /** 預設 `high`。 */
  accuracy?: LocationAccuracy
  /** 位移超過這個公尺數才更新，0 到 10,000，預設 0（不過濾）。 */
  distanceFilterMeters?: number
  /** 更新間隔提示，500 到 3,600,000；只有 Android 使用，其他平台忽略。 */
  intervalMs?: number
}

/** 定位的錯誤碼。 */
export type LocationErrorCode =
  | 'invalid_argument'
  | 'permission_denied'
  | 'location_services_disabled'
  | 'timeout'
  | 'position_unavailable'
  | 'too_many_watches'

/** 此 plugin 的契約：方法表與事件表。Dart 端 `LocationPlugin` 必須提供同名方法與事件（契約 rev 1）。 */
export type LocationContract = PluginDefinition<
  {
    capabilities: { req: Record<string, never>, res: LocationCapabilities }
    requestPermission: { req: Record<string, never>, res: { permission: PermissionStatus } }
    getCurrentPosition: { req: CurrentPositionOptions, res: { position: Position } }
    startWatching: { req: WatchOptions, res: { watchId: number } }
    stopWatching: { req: { watchId: number }, res: Record<string, never> }
    openSettings: { req: { target: 'app' | 'location' }, res: Record<string, never> }
  },
  {
    position: { watchId: number, position: Position }
    error: { watchId: number, code: LocationErrorCode }
  }
>

// 把契約併入全域 plugin 表：使用端即可用 callPlugin('location', …) 得到完整型別
declare module '@aqutter/aqutter' {
  interface AqutterPluginRegistry {
    location: LocationContract
  }
}

/**
 * 網頁端 API。**前景定位**：App 在使用中才保證運作，不做背景定位。位置不保存、不寫日誌。
 *
 * 權限由網頁先要（`requestPermission`），沒有授權時 `getCurrentPosition`／`startWatching` 回 `permission_denied`，
 * 不會自己跳授權視窗。失敗時 `callPlugin` 拋出 `AqutterPluginError`，其 `code` 是 {@link LocationErrorCode}。
 *
 * **plugin 在這個平台用不了時不拋錯**（Linux 等）：`capabilities` 回「服務關閉、權限 denied」，
 * `requestPermission` 回 `denied`，`getCurrentPosition` 回 `null`，`startWatching` 回 `null`，其餘不做事。
 */
export const location = {
  capabilities: async (): Promise<LocationCapabilities> =>
    (await callPlugin('location', 'capabilities', {})) ?? { serviceEnabled: false, permission: 'denied' },
  /** 必要時跳系統授權視窗，回傳授權後的狀態。 */
  requestPermission: async (): Promise<PermissionStatus> =>
    (await callPlugin('location', 'requestPermission', {}))?.permission ?? 'denied',
  /** 取得目前位置一次，不快取；不支援的平台回 `null`。 */
  getCurrentPosition: async (options: CurrentPositionOptions = {}): Promise<Position | null> =>
    (await callPlugin('location', 'getCurrentPosition', options))?.position ?? null,
  /**
   * 開始持續監聽，位置以 `listener` 推送；回傳停止函式。不支援的平台回 `null`。
   * 錯誤以 `onError` 推送（暫時性的錯誤不會結束監聽；`permission_denied`、`location_services_disabled` 會先通知再結束）。
   * 停止函式是非同步的：`await` 它確定已停止。
   */
  watch: async (
    listener: (position: Position) => void,
    options: WatchOptions & { onError?: (code: LocationErrorCode) => void } = {},
  ): Promise<(() => Promise<void>) | null> => {
    const { onError, ...watchOptions } = options
    // 先訂閱再開始，才不會漏掉第一筆；事件以 watchId 區分是哪個監聽
    let watchId: number | null = null
    const early: Array<{ watchId: number, position: Position }> = []
    const stopPositions = onPluginEvent('location', 'position', (event) => {
      if (watchId === null) {
        early.push(event)
      }
      else if (event.watchId === watchId) {
        listener(event.position)
      }
    })
    const stopErrors = onPluginEvent('location', 'error', (event) => {
      if (watchId !== null && event.watchId === watchId) {
        onError?.(event.code)
      }
    })
    let started: { watchId: number } | undefined
    try {
      started = await callPlugin('location', 'startWatching', watchOptions)
    }
    catch (error) {
      stopPositions()
      stopErrors()
      throw error
    }
    if (started === undefined) {
      stopPositions()
      stopErrors()
      return null
    }
    watchId = started.watchId
    for (const event of early) {
      if (event.watchId === watchId) {
        listener(event.position)
      }
    }
    return async () => {
      stopPositions()
      stopErrors()
      await callPlugin('location', 'stopWatching', { watchId: watchId as number })
    }
  },
  /** `app`：本 App 的系統設定（永久拒絕權限後使用）；`location`：系統的定位服務設定。 */
  openSettings: async (target: 'app' | 'location'): Promise<void> => {
    await callPlugin('location', 'openSettings', { target })
  },
}
