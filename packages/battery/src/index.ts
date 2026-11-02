import { callPlugin, isPluginSupported, onPluginEvent } from '@aqutter/aqutter'
import type { PluginDefinition } from '@aqutter/aqutter'

export type BatteryStateName = 'full' | 'charging' | 'discharging' | 'connectedNotCharging' | 'unknown'

/** battery plugin 的契約。Dart 端 `BatteryPlugin` 提供同名方法與事件。 */
export type BatteryContract = PluginDefinition<
  {
    level: { req: void, res: { level: number } }
    state: { req: void, res: { state: BatteryStateName } }
    saveMode: { req: void, res: { enabled: boolean } }
  },
  {
    stateChanged: { state: BatteryStateName }
  }
>

declare module '@aqutter/aqutter' {
  interface AqutterPluginRegistry {
    battery: BatteryContract
  }
}

/** 網頁端 API。 */
export const battery = {
  isSupported: (): boolean => isPluginSupported('battery', 'level'),
  /** 電量百分比；這個平台沒有電池資訊（plugin 用不了）時回 `null`。 */
  level: async (): Promise<number | null> => (await callPlugin('battery', 'level'))?.level ?? null,
  /** 充電狀態；plugin 用不了時回 `'unknown'`。 */
  state: async (): Promise<BatteryStateName> => (await callPlugin('battery', 'state'))?.state ?? 'unknown',
  isInSaveMode: async (): Promise<boolean> => (await callPlugin('battery', 'saveMode'))?.enabled ?? false,
  /** 充電狀態改變時通知；回傳取消訂閱函式。 */
  onStateChanged: (listener: (state: BatteryStateName) => void): (() => void) =>
    onPluginEvent('battery', 'stateChanged', payload => listener(payload.state)),
}
