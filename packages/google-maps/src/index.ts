import { defineAqutterNative, isPluginSupported } from '@aqutter/aqutter'
import type { AqutterNativeElement, PluginDefinition } from '@aqutter/aqutter'
import { createJsView } from './jsProvider'
import { GOOGLE_MAPS_SESSION, createNativeView } from './nativeProvider'
import type {
  GoogleMapsCamera,
  GoogleMapsMarker,
  GoogleMapsMountOptions,
  GoogleMapsProvider,
  GoogleMapsType,
  GoogleMapsView,
} from './view'

export type {
  GoogleMapsCamera,
  GoogleMapsMarker,
  GoogleMapsMountOptions,
  GoogleMapsMoveOptions,
  GoogleMapsProvider,
  GoogleMapsType,
  GoogleMapsUnsubscribe,
  GoogleMapsView,
} from './view'
export { GOOGLE_MAPS_SESSION }

/** google-maps plugin 的契約（`native` provider 用）。Dart 端 `GoogleMapsPlugin` 提供同名方法與事件。 */
export type GoogleMapsContract = PluginDefinition<
  {
    getCamera: { req: void, res: GoogleMapsCamera }
    moveTo: { req: { lat: number, lng: number, zoom?: number, animate?: boolean }, res: { ok: boolean } }
    setMarkers: { req: { markers: GoogleMapsMarker[] }, res: { count: number } }
    setMapType: { req: { type: GoogleMapsType }, res: { type: string } }
  },
  {
    ready: { camera: GoogleMapsCamera }
    cameraIdle: GoogleMapsCamera
    tap: { lat: number, lng: number }
  }
>

declare module '@aqutter/aqutter' {
  interface AqutterPluginRegistry {
    'google-maps': GoogleMapsContract
  }
}

export interface GoogleMapsConfig {
  /** Google Maps JavaScript API key（非原生平台用）；由使用端 App 傳入，不要寫進會提交的檔案。 */
  jsApiKey?: string
}

let config: GoogleMapsConfig = {}

/**
 * 網頁端 API。
 *
 * 用法：先（需要時）`configure({ jsApiKey })`，再 `await googleMaps.mount(container)` 取得 `GoogleMapsView`。
 * iOS、Android 走原生地圖；其他平台（以及純瀏覽器）走 Google Maps JavaScript API。
 */
export const googleMaps = {
  /** 設定非原生平台用的 Google Maps JavaScript API key；須在 `mount` 前呼叫，原生平台忽略。 */
  configure: (options: GoogleMapsConfig): void => {
    config = { ...config, ...options }
  },
  /**
   * 目前平台用哪個 provider（同步）。依殼回報的能力表判斷：plugin 在本平台有原生實作才是 `'native'`。
   * 殼的平台資訊尚未載入時（啟動早期）一律視為支援，會回 `'native'`——請在 App 的平台資訊就緒後再 `mount`。
   */
  provider: (): GoogleMapsProvider => (isPluginSupported('google-maps', 'moveTo') ? 'native' : 'js'),
  /** 註冊 `<aqutter-native>` 元素（冪等）。`mount` 會自己呼叫；只有要自己放元素時才需要。 */
  define: (): void => defineAqutterNative(),
  /**
   * 在 `container` 內建立地圖並回傳控制介面。container 內可以再疊任何 HTML。
   *
   * `'js'` provider 沒有先 `configure({ jsApiKey })`、或腳本載入失敗／逾時，都會 reject。
   */
  mount: async (container: HTMLElement, options: GoogleMapsMountOptions = {}): Promise<GoogleMapsView> => {
    if (googleMaps.provider() === 'native') {
      return createNativeView(container, options)
    }
    if (!config.jsApiKey) {
      throw new Error('[googleMaps] this platform uses the Google Maps JavaScript API: call googleMaps.configure({ jsApiKey }) before mount()')
    }
    return createJsView(container, options, config.jsApiKey)
  },
  /** 取得頁面上顯示原生地圖的 `<aqutter-native>` 元素（只有 `'native'` provider 有）。 */
  element: (root: ParentNode = document): AqutterNativeElement | null =>
    root.querySelector<AqutterNativeElement>(`aqutter-native[session="${GOOGLE_MAPS_SESSION}"]`),
}
