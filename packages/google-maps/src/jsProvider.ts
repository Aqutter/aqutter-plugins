import { loadGoogleMaps } from './loadGoogleMaps'
import type {
  GoogleMapsCamera,
  GoogleMapsMarker,
  GoogleMapsMountOptions,
  GoogleMapsMoveOptions,
  GoogleMapsType,
  GoogleMapsUnsubscribe,
  GoogleMapsView,
} from './view'

const MAP_TYPE_IDS: Record<GoogleMapsType, string> = {
  normal: 'roadmap',
  satellite: 'satellite',
  terrain: 'terrain',
  hybrid: 'hybrid',
}

const DEFAULT_CENTER = { lat: 0, lng: 0 }
const DEFAULT_ZOOM = 2

type Listener<T> = (value: T) => void

const subscribe = <T>(set: Set<Listener<T>>, listener: Listener<T>): GoogleMapsUnsubscribe => {
  set.add(listener)
  return () => {
    set.delete(listener)
  }
}

/** `'js'` provider：在 container 內以 Google Maps JavaScript API 建立地圖。 */
export const createJsView = async (
  container: HTMLElement,
  options: GoogleMapsMountOptions,
  apiKey: string,
): Promise<GoogleMapsView> => {
  const maps = await loadGoogleMaps(apiKey)

  const element = document.createElement('div')
  element.style.cssText = 'position:absolute;inset:0;width:100%;height:100%'
  if (getComputedStyle(container).position === 'static') {
    container.style.position = 'relative'
  }
  container.prepend(element)

  const map = new maps.Map(element, {
    center: options.camera ? { lat: options.camera.lat, lng: options.camera.lng } : DEFAULT_CENTER,
    zoom: options.camera?.zoom ?? DEFAULT_ZOOM,
    mapTypeId: MAP_TYPE_IDS[options.mapType ?? 'normal'],
    disableDefaultUI: true,
    clickableIcons: false,
  })

  const camera = (): GoogleMapsCamera => {
    const center = map.getCenter()
    return { lat: center?.lat() ?? DEFAULT_CENTER.lat, lng: center?.lng() ?? DEFAULT_CENTER.lng, zoom: map.getZoom() ?? DEFAULT_ZOOM }
  }

  const ready = new Set<Listener<GoogleMapsCamera>>()
  const idle = new Set<Listener<GoogleMapsCamera>>()
  const tap = new Set<Listener<{ lat: number, lng: number }>>()
  let markers: google.maps.Marker[] = []
  let destroyed = false

  const handles = [
    map.addListener('idle', () => {
      const position = camera()
      for (const listener of [...idle]) {
        listener(position)
      }
    }),
    map.addListener('click', (event: google.maps.MapMouseEvent) => {
      if (!event.latLng) {
        return
      }
      const position = { lat: event.latLng.lat(), lng: event.latLng.lng() }
      for (const listener of [...tap]) {
        listener(position)
      }
    }),
  ]

  // 與原生 provider 一致：地圖建立完成就通知一次。用 setTimeout 而不是 microtask：
  // 要等呼叫端 await 拿到 view、註冊好 onReady 之後才派送；microtask 會比呼叫端的後續動作更早執行。
  setTimeout(() => {
    if (destroyed) {
      return
    }
    const position = camera()
    for (const listener of [...ready]) {
      listener(position)
    }
  }, 0)

  return {
    provider: 'js',
    getCamera: async () => camera(),
    moveTo: async (lat: number, lng: number, move: GoogleMapsMoveOptions = {}) => {
      if (move.zoom !== undefined) {
        map.setZoom(move.zoom)
      }
      if (move.animate) {
        map.panTo({ lat, lng })
      }
      else {
        map.setCenter({ lat, lng })
      }
    },
    setMarkers: async (next: GoogleMapsMarker[]) => {
      for (const marker of markers) {
        marker.setMap(null)
      }
      markers = next.map(entry => new maps.Marker({
        map,
        position: { lat: entry.lat, lng: entry.lng },
        title: entry.title,
      }))
    },
    setMapType: async (type: GoogleMapsType) => {
      map.setMapTypeId(MAP_TYPE_IDS[type])
    },
    onReady: listener => subscribe(ready, listener),
    onCameraIdle: listener => subscribe(idle, listener),
    onTap: listener => subscribe(tap, listener),
    destroy: () => {
      destroyed = true
      for (const handle of handles) {
        handle.remove()
      }
      for (const marker of markers) {
        marker.setMap(null)
      }
      markers = []
      ready.clear()
      idle.clear()
      tap.clear()
      element.remove()
    },
  }
}
