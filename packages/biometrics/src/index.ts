import { callPlugin, onPluginEvent } from '@aqutter/aqutter'
import type { PluginDefinition } from '@aqutter/aqutter'

/** 此 plugin 的契約：方法表與事件表。Dart 端 `BiometricsPlugin` 必須提供同名方法。 */
export type BiometricsContract = PluginDefinition<
  {
    ping: { req: { message: string }, res: { echo: string } }
  },
  {
    tick: { count: number }
  }
>

// 把契約併入全域 plugin 表：使用端即可用 callPlugin('biometrics', …) 得到完整型別
declare module '@aqutter/aqutter' {
  interface AqutterPluginRegistry {
    'biometrics': BiometricsContract
  }
}

/** 網頁端 API。 */
export const biometrics = {
  ping: (message: string) => callPlugin('biometrics', 'ping', { message }),
  onTick: (listener: (count: number) => void) => onPluginEvent('biometrics', 'tick', payload => listener(payload.count)),
}
