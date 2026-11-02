import { callPlugin, isPluginSupported } from '@aqutter/aqutter'
import type { PluginDefinition } from '@aqutter/aqutter'

export type HapticStyle = 'light' | 'medium' | 'heavy'

/** haptics plugin 的契約。Dart 端 `HapticsPlugin` 提供同名方法。 */
export type HapticsContract = PluginDefinition<
  {
    impact: { req: { style: HapticStyle }, res: { ok: true } }
    selection: { req: void, res: { ok: true } }
    vibrate: { req: void, res: { ok: true } }
  },
  Record<never, never>
>

declare module '@aqutter/aqutter' {
  interface AqutterPluginRegistry {
    haptics: HapticsContract
  }
}

/** 網頁端 API。不在殼內（或殼沒裝此 plugin）時，各方法安靜地什麼都不做。 */
export const haptics = {
  isSupported: (): boolean => isPluginSupported('haptics', 'impact'),
  impact: async (style: HapticStyle = 'medium'): Promise<void> => {
    if (haptics.isSupported()) {
      await callPlugin('haptics', 'impact', { style })
    }
  },
  selection: async (): Promise<void> => {
    if (haptics.isSupported()) {
      await callPlugin('haptics', 'selection')
    }
  },
  vibrate: async (): Promise<void> => {
    if (haptics.isSupported()) {
      await callPlugin('haptics', 'vibrate')
    }
  },
}
