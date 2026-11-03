import type { PluginDefinition } from '@aqutter/aqutter'

/** 與 Dart 端 `NearbyDemoPlugin.id` 一致。 */
export const NEARBY_DEMO_ID = 'nearby-demo'

export interface NearbySnapshot {
  serviceEnabled: boolean
  permission: string
  position: { latitude: number, longitude: number, accuracy: number } | null
}

/**
 * 此 plugin 的契約。**不**併入 `AqutterPluginRegistry`：它是 `internal`，網頁不能直接呼叫，
 * 只有別的 plugin 的 Dart 端能經 `context.callPlugin('nearby-demo', 'snapshot')` 使用；
 * 網頁端請用封裝它的 plugin（例如 `aqutter-plugin-place-demo`）。
 */
export type NearbyDemoContract = PluginDefinition<
  {
    snapshot: { req: Record<string, never>, res: NearbySnapshot }
  },
  {}
>
