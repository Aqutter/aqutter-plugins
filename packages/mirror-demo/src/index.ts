import { callPlugin, defineAqutterNative, onPluginEvent } from '@aqutter/aqutter'
import type { AqutterNativeElement, PluginDefinition } from '@aqutter/aqutter'

/** mirror-demo plugin 的契約。 */
export type MirrorDemoContract = PluginDefinition<
  {
    state: { req: void, res: { x: number, y: number, radius: number, count: number } }
  },
  {
    count: { count: number }
  }
>

declare module '@aqutter/aqutter' {
  interface AqutterPluginRegistry {
    'mirror-demo': MirrorDemoContract
  }
}

/** 與 Dart 端 `AqutterNative.sessionId` 一致。 */
export const MIRROR_DEMO_SESSION = 'mirror-demo'

/** 網頁端 API。 */
export const mirrorDemo = {
  /** 註冊 `<aqutter-native>` 元素（冪等）；之後在頁面放 `<aqutter-native session="mirror-demo">` 即可。 */
  define: (): void => defineAqutterNative(),
  state: () => callPlugin('mirror-demo', 'state'),
  onCount: (listener: (count: number) => void): (() => void) =>
    onPluginEvent('mirror-demo', 'count', payload => listener(payload.count)),
  /** 對指定的 `<aqutter-native>` 元素送出 reset 指令。 */
  reset: (element: AqutterNativeElement): boolean => element.sendCommand('reset'),
}
