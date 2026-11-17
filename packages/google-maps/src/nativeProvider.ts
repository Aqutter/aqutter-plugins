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

type GesturePayload = { type: 'pan' | 'pinch' | 'doubleTap' | 'tap' } & Record<string, unknown>

/**
 * 實驗（不鏡像模式）：把元素上的 pointer 事件換成 `AqutterMapGestureMapper` 吃的語意手勢送給 plugin。
 * 位移與位置都是相對元素大小的 0..1 正規化值；單指拖曳＝pan、雙指＝pinch（帶累計倍率）、短按＝tap、連按兩下＝doubleTap。
 * pan 與 pinch 的更新每個畫面只送一次（plugin 端也會合併），避免觸控事件洪水。回傳取消監聽的函式。
 */
export const forwardGestures = (element: HTMLElement): (() => void) => {
  const send = (payload: GesturePayload): void => {
    void callPlugin('google-maps', 'gesture', payload).catch(() => {})
  }
  const pointers = new Map<number, { x: number, y: number }>()
  let pending: GesturePayload | null = null
  let panDx = 0
  let panDy = 0
  let pinchStartDistance = 0
  let frame = 0
  let downAt = 0
  let moved = false
  let downPoint = { x: 0, y: 0 }
  let lastTapAt = Number.NEGATIVE_INFINITY
  const TAP_MS = 250
  const DOUBLE_TAP_MS = 300
  const TAP_SLOP = 8

  // 底層地圖是滿版（與視窗同大），所以位置與位移一律以視窗大小正規化；元素本身可以比視窗小（圓角卡片、遮罩區）
  const norm = (x: number, y: number): { x: number, y: number } => ({
    x: x / (window.innerWidth || 1),
    y: y / (window.innerHeight || 1),
  })
  const two = (): [{ x: number, y: number }, { x: number, y: number }] => {
    const [a, b] = [...pointers.values()]
    return [a!, b!]
  }
  const distance = (): number => {
    const [a, b] = two()
    return Math.hypot(a.x - b.x, a.y - b.y)
  }
  const flush = (): void => {
    frame = 0
    if (panDx !== 0 || panDy !== 0) {
      send({ type: 'pan', phase: 'update', dx: panDx / (window.innerWidth || 1), dy: panDy / (window.innerHeight || 1) })
      panDx = 0
      panDy = 0
    }
    if (pending) {
      send(pending)
      pending = null
    }
  }
  const schedule = (): void => {
    if (frame === 0) {
      frame = requestAnimationFrame(flush)
    }
  }

  const onDown = (event: PointerEvent): void => {
    element.setPointerCapture(event.pointerId)
    pointers.set(event.pointerId, { x: event.clientX, y: event.clientY })
    if (pointers.size === 1) {
      downAt = event.timeStamp
      moved = false
      downPoint = { x: event.clientX, y: event.clientY }
    }
    if (pointers.size === 2) {
      moved = true
      pinchStartDistance = distance() || 1
      const [a, b] = two()
      const center = norm((a.x + b.x) / 2, (a.y + b.y) / 2)
      send({ type: 'pinch', phase: 'start', x: center.x, y: center.y })
    }
  }
  const onMove = (event: PointerEvent): void => {
    const previous = pointers.get(event.pointerId)
    if (!previous) {
      return
    }
    const next = { x: event.clientX, y: event.clientY }
    pointers.set(event.pointerId, next)
    if (pointers.size === 1) {
      moved = moved || Math.hypot(next.x - downPoint.x, next.y - downPoint.y) > TAP_SLOP
      panDx += next.x - previous.x
      panDy += next.y - previous.y
      schedule()
    }
    else if (pointers.size === 2) {
      const [a, b] = two()
      const center = norm((a.x + b.x) / 2, (a.y + b.y) / 2)
      pending = { type: 'pinch', phase: 'update', x: center.x, y: center.y, scale: distance() / pinchStartDistance }
      schedule()
    }
  }
  const onUp = (event: PointerEvent): void => {
    if (!pointers.has(event.pointerId)) {
      return
    }
    const wasTwo = pointers.size === 2
    const point = pointers.get(event.pointerId)!
    pointers.delete(event.pointerId)
    if (wasTwo) {
      flush()
      send({ type: 'pinch', phase: 'end' })
      return
    }
    flush()
    if (!moved && event.timeStamp - downAt < TAP_MS) {
      const position = norm(point.x, point.y)
      if (event.timeStamp - lastTapAt < DOUBLE_TAP_MS) {
        lastTapAt = Number.NEGATIVE_INFINITY
        send({ type: 'doubleTap', x: position.x, y: position.y })
      }
      else {
        lastTapAt = event.timeStamp
        send({ type: 'tap', x: position.x, y: position.y })
      }
    }
  }

  element.addEventListener('pointerdown', onDown)
  element.addEventListener('pointermove', onMove)
  element.addEventListener('pointerup', onUp)
  element.addEventListener('pointercancel', onUp)
  return () => {
    cancelAnimationFrame(frame)
    element.removeEventListener('pointerdown', onDown)
    element.removeEventListener('pointermove', onMove)
    element.removeEventListener('pointerup', onUp)
    element.removeEventListener('pointercancel', onUp)
  }
}

/**
 * 實驗（不鏡像模式）：追蹤放地圖的容器（洞）的位置與大小，回報給 plugin。
 * 觸發：元素大小改變（ResizeObserver）、任何捲動容器捲動（捕獲階段的 scroll，不必知道哪個祖先在捲）、視窗大小改變。
 * 每個畫面最多送一次，並附送出時間 `sentAt`（毫秒時間戳），讓 Dart 端量傳遞延遲。回傳取消追蹤的函式。
 */
export const trackLayout = (element: HTMLElement): (() => void) => {
  let frame = 0
  const send = (): void => {
    frame = 0
    const rect = element.getBoundingClientRect()
    void callPlugin('google-maps', 'layout', { left: rect.left, top: rect.top, width: rect.width, height: rect.height, sentAt: Date.now() }).catch(() => {})
  }
  const schedule = (): void => {
    if (frame === 0) {
      frame = requestAnimationFrame(send)
    }
  }
  const observer = typeof ResizeObserver === 'undefined' ? null : new ResizeObserver(schedule)
  observer?.observe(element)
  window.addEventListener('scroll', schedule, { capture: true, passive: true })
  window.addEventListener('resize', schedule, { passive: true })
  send()
  return () => {
    cancelAnimationFrame(frame)
    observer?.disconnect()
    window.removeEventListener('scroll', schedule, { capture: true })
    window.removeEventListener('resize', schedule)
  }
}

/** `'native'` provider：在 container 內建立 `<aqutter-native>`，鏡像原生地圖（iOS、Android）。 */
export const createNativeView = async (
  container: HTMLElement,
  options: GoogleMapsMountOptions,
): Promise<GoogleMapsView> => {
  // 實驗（不鏡像模式）：殼回報 passthrough 時，地圖直接畫在透明 WebView 下面，這裡只放一層接觸控的透明元素
  const passthrough = await callPlugin('google-maps', 'mode').then(result => result?.passthrough === true, () => false)
  let element: HTMLElement
  let stopGestures = (): void => {}
  if (passthrough) {
    element = document.createElement('div')
    element.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;background:transparent;touch-action:none'
    const stopPointer = forwardGestures(element)
    await callPlugin('google-maps', 'show')
    // `show` 之後才送洞的位置（`show` 會重置它）；camera 選項在這之後才套用，相機中心才會落在洞的中心
    const stopLayout = trackLayout(element)
    stopGestures = () => {
      stopPointer()
      stopLayout()
    }
  }
  else {
    defineAqutterNative()
    element = document.createElement('aqutter-native')
    element.setAttribute('session', GOOGLE_MAPS_SESSION)
    element.setAttribute('fit', 'cover')
    element.style.cssText = 'position:absolute;inset:0;width:100%;height:100%'
  }
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
    // 原生地圖用不了時（只有在 isPluginSupported 為 false 卻仍呼叫才會發生）回 0,0,0，不拋錯
    getCamera: async () => (await callPlugin('google-maps', 'getCamera')) ?? { lat: 0, lng: 0, zoom: 0 },
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
      stopGestures()
      if (passthrough) {
        void callPlugin('google-maps', 'hide').catch(() => {})
      }
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
