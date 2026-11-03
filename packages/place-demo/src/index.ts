import { callPlugin } from '@aqutter/aqutter'
import type { PluginDefinition } from '@aqutter/aqutter'

export interface WhereAmIResult {
  /** 呼叫鏈：網頁只認識第一個，其餘由 Dart 端逐層轉呼叫。 */
  layers: string[]
  /** 定位服務開著且已授權。 */
  ready: boolean
  permission: string
  /** 沒有權限、服務關閉或逾時時為 `null`。 */
  position: { latitude: number, longitude: number, accuracy: number } | null
}

/** 此 plugin 的契約：方法表與事件表。Dart 端 `PlaceDemoPlugin` 必須提供同名方法（契約 rev 1）。 */
export type PlaceDemoContract = PluginDefinition<
  {
    whereAmI: { req: Record<string, never>, res: WhereAmIResult }
  },
  {}
>

// 把契約併入全域 plugin 表：使用端即可用 callPlugin('place-demo', …) 得到完整型別
declare module '@aqutter/aqutter' {
  interface AqutterPluginRegistry {
    'place-demo': PlaceDemoContract
  }
}

/**
 * 網頁端 API。回傳 `undefined` 代表 plugin 在這裡用不了（例如不是 Flutter 殼）。
 * 底下的 `nearby-demo` 與 `location` 對網頁不可見，這裡不需要也不應該直接呼叫它們。
 */
export const placeDemo = {
  whereAmI: () => callPlugin('place-demo', 'whereAmI', {}),
}
