import { callPlugin, onPluginEvent } from '@aqutter/aqutter'
import type { PluginDefinition } from '@aqutter/aqutter'

/** 此 plugin 的契約：方法表與事件表。Dart 端 `LocationPlugin` 必須提供同名方法。 */
export type LocationContract = PluginDefinition<
  {
    ping: { req: { message: string }, res: { echo: string } }
  },
  {
    tick: { count: number }
  }
>

// 把契約併入全域 plugin 表：使用端即可用 callPlugin('location', …) 得到完整型別
declare module '@aqutter/aqutter' {
  interface AqutterPluginRegistry {
    'location': LocationContract
  }
}

/** 網頁端 API。 */
export const location = {
  ping: (message: string) => callPlugin('location', 'ping', { message }),
  onTick: (listener: (count: number) => void) => onPluginEvent('location', 'tick', payload => listener(payload.count)),
}
