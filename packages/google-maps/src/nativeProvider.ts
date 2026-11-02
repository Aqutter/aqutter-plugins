import { callPlugin, defineAqutterNative, onPluginEvent } from '@aqutter/aqutter'
import type {
  GoogleMapsMarker,
  GoogleMapsMountOptions,
  GoogleMapsMoveOptions,
  GoogleMapsType,
  GoogleMapsView,
} from './view'

/** 與 Dart 端 `aqutterGoogleMapsSession` 一致。 */
export const GOOGLE_MAPS_SESSION = 'google-maps'

/** `'native'` provider：在 container 內建立 `<aqutter-native>`，鏡像原生地圖（iOS、Android）。 */
export const createNativeView = async (
  container: HTMLElement,
  options: GoogleMapsMountOptions,
): Promise<GoogleMapsView> => {
  defineAqutterNative()
  const element = document.createElement('aqutter-native')
  element.setAttribute('session', GOOGLE_MAPS_SESSION)
  element.setAttribute('fit', 'cover')
  element.style.cssText = 'position:absolute;inset:0;width:100%;height:100%'
  if (getComputedStyle(container).position === 'static') {
    container.style.position = 'relative'
  }
  container.prepend(element)

  const unsubscribers = new Set<() => void>()
  const listen = <T>(subscribe: (listener: (value: T) => void) => () => void, listener: (value: T) => void): (() => void) => {
    const stop = subscribe(listener)
    unsubscribers.add(stop)
    return () => {
      stop()
      unsubscribers.delete(stop)
    }
  }

  const view: GoogleMapsView = {
    provider: 'native',
    getCamera: () => callPlugin('google-maps', 'getCamera'),
    moveTo: async (lat: number, lng: number, move: GoogleMapsMoveOptions = {}) => {
      await callPlugin('google-maps', 'moveTo', { lat, lng, ...move })
    },
    setMarkers: async (markers: GoogleMapsMarker[]) => {
      await callPlugin('google-maps', 'setMarkers', { markers })
    },
    setMapType: async (type: GoogleMapsType) => {
      await callPlugin('google-maps', 'setMapType', { type })
    },
    onReady: listener => listen(l => onPluginEvent('google-maps', 'ready', payload => l(payload.camera)), listener),
    onCameraIdle: listener => listen(l => onPluginEvent('google-maps', 'cameraIdle', l), listener),
    onTap: listener => listen(l => onPluginEvent('google-maps', 'tap', l), listener),
    destroy: () => {
      for (const stop of unsubscribers) {
        stop()
      }
      unsubscribers.clear()
      element.remove()
    },
  }

  if (options.mapType) {
    await view.setMapType(options.mapType)
  }
  if (options.camera) {
    await view.moveTo(options.camera.lat, options.camera.lng, options.camera.zoom === undefined ? {} : { zoom: options.camera.zoom })
  }
  return view
}
