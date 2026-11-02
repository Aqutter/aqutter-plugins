import { callPlugin, onPluginEvent } from '@aqutter/aqutter'
import type { PluginDefinition } from '@aqutter/aqutter'

/** 此 plugin 的契約：方法表與事件表。Dart 端 `SecureStoragePlugin` 必須提供同名方法。 */
export type SecureStorageContract = PluginDefinition<
  {
    ping: { req: { message: string }, res: { echo: string } }
  },
  {
    tick: { count: number }
  }
>

// 把契約併入全域 plugin 表：使用端即可用 callPlugin('secure-storage', …) 得到完整型別
declare module '@aqutter/aqutter' {
  interface AqutterPluginRegistry {
    'secure-storage': SecureStorageContract
  }
}

/** 網頁端 API。 */
export const secure_storage = {
  ping: (message: string) => callPlugin('secure-storage', 'ping', { message }),
  onTick: (listener: (count: number) => void) => onPluginEvent('secure-storage', 'tick', payload => listener(payload.count)),
}
