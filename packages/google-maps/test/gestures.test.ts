// @vitest-environment happy-dom
import { beforeEach, describe, expect, it, vi } from 'vitest'

const bridge = vi.hoisted(() => ({
  calls: [] as { method: string, payload: Record<string, unknown> }[],
  passthrough: true,
}))

vi.mock('@aqutter/aqutter', () => ({
  defineAqutterNative: () => {},
  isPluginSupported: () => true,
  callPlugin: async (_id: string, method: string, payload?: Record<string, unknown>) => {
    if (method === 'mode') {
      return { passthrough: bridge.passthrough }
    }
    bridge.calls.push({ method, payload: payload ?? {} })
    return { ok: true }
  },
  onPluginEvent: () => () => {},
}))

const { forwardGestures, trackLayout } = await import('../src/nativeProvider')
const { googleMaps } = await import('../src/index')

const pointer = (type: string, id: number, x: number, y: number, timeStamp = 0): PointerEvent => {
  const event = new PointerEvent(type, { pointerId: id, clientX: x, clientY: y, bubbles: true })
  Object.defineProperty(event, 'timeStamp', { value: timeStamp })
  return event
}

const frame = (): Promise<void> => new Promise(resolve => requestAnimationFrame(() => resolve()))

describe('forwardGestures', () => {
  let element: HTMLElement
  beforeEach(() => {
    bridge.calls = []
    document.body.innerHTML = '<div id="map"></div>'
    element = document.getElementById('map') as HTMLElement
    // 視窗 200x100；元素比視窗小時位置與位移仍以視窗大小正規化
    Object.defineProperty(window, 'innerWidth', { value: 200, configurable: true })
    Object.defineProperty(window, 'innerHeight', { value: 100, configurable: true })
    element.getBoundingClientRect = () => ({ left: 20, top: 10, width: 100, height: 50, right: 120, bottom: 60, x: 20, y: 10, toJSON: () => ({}) })
    element.setPointerCapture = () => {}
  })

  it('sends a normalized pan update once per frame', async () => {
    const stop = forwardGestures(element)
    element.dispatchEvent(pointer('pointerdown', 1, 100, 50))
    element.dispatchEvent(pointer('pointermove', 1, 120, 50))
    element.dispatchEvent(pointer('pointermove', 1, 140, 60))
    await frame()
    const pans = bridge.calls.filter(call => call.payload.type === 'pan')
    expect(pans).toHaveLength(1)
    expect(pans[0]!.payload).toMatchObject({ phase: 'update', dx: 40 / 200, dy: 10 / 100 })
    stop()
  })

  it('sends a tap for a short press without movement', () => {
    forwardGestures(element)
    element.dispatchEvent(pointer('pointerdown', 1, 50, 25, 0))
    element.dispatchEvent(pointer('pointerup', 1, 50, 25, 100))
    expect(bridge.calls.at(-1)?.payload).toEqual({ type: 'tap', x: 0.25, y: 0.25 })
  })

  it('sends doubleTap for two quick taps', () => {
    forwardGestures(element)
    element.dispatchEvent(pointer('pointerdown', 1, 50, 25, 0))
    element.dispatchEvent(pointer('pointerup', 1, 50, 25, 50))
    element.dispatchEvent(pointer('pointerdown', 1, 50, 25, 150))
    element.dispatchEvent(pointer('pointerup', 1, 50, 25, 200))
    expect(bridge.calls.map(call => call.payload.type)).toEqual(['tap', 'doubleTap'])
  })

  it('sends pinch start, cumulative scale, end for two pointers', async () => {
    forwardGestures(element)
    element.dispatchEvent(pointer('pointerdown', 1, 80, 50))
    element.dispatchEvent(pointer('pointerdown', 2, 120, 50))
    element.dispatchEvent(pointer('pointermove', 2, 160, 50))
    await frame()
    element.dispatchEvent(pointer('pointerup', 2, 160, 50))
    const phases = bridge.calls.filter(call => call.payload.type === 'pinch').map(call => call.payload.phase)
    expect(phases).toEqual(['start', 'update', 'end'])
    const update = bridge.calls.find(call => call.payload.phase === 'update')!
    expect(update.payload.scale).toBeCloseTo(80 / 40)
  })
})

describe('googleMaps.mount in passthrough mode', () => {
  it('uses a transparent div instead of aqutter-native', async () => {
    bridge.passthrough = true
    bridge.calls = []
    document.body.innerHTML = '<div id="box"></div>'
    const view = await googleMaps.mount(document.getElementById('box') as HTMLElement)
    expect(document.querySelector('aqutter-native')).toBeNull()
    expect(document.querySelector('#box > div')).not.toBeNull()
    expect(bridge.calls.map(call => call.method)).toContain('show')
    view.destroy()
    expect(document.querySelector('#box > div')).toBeNull()
    expect(bridge.calls.map(call => call.method)).toContain('hide')
  })

  it('keeps aqutter-native when the plugin is not in passthrough mode', async () => {
    bridge.passthrough = false
    bridge.calls = []
    document.body.innerHTML = '<div id="box"></div>'
    const view = await googleMaps.mount(document.getElementById('box') as HTMLElement)
    expect(document.querySelector('aqutter-native')).not.toBeNull()
    expect(bridge.calls.map(call => call.method)).not.toContain('show')
    view.destroy()
  })
})

describe('trackLayout', () => {
  const frame = (): Promise<void> => new Promise(resolve => requestAnimationFrame(() => resolve()))

  it('reports the rect immediately and again after a scroll, once per frame', async () => {
    bridge.calls = []
    document.body.innerHTML = '<div id="hole"></div>'
    const element = document.getElementById('hole') as HTMLElement
    let top = 200
    element.getBoundingClientRect = () => ({ left: 40, top, width: 320, height: 300, right: 360, bottom: top + 300, x: 40, y: top, toJSON: () => ({}) })
    const stop = trackLayout(element)
    const layouts = () => bridge.calls.filter(call => call.method === 'layout')
    expect(layouts()).toHaveLength(1)
    expect(layouts()[0]!.payload).toMatchObject({ left: 40, top: 200, width: 320, height: 300 })
    expect(typeof layouts()[0]!.payload.sentAt).toBe('number')

    top = 150
    window.dispatchEvent(new Event('scroll'))
    window.dispatchEvent(new Event('scroll'))
    await frame()
    expect(layouts()).toHaveLength(2)
    expect(layouts()[1]!.payload).toMatchObject({ top: 150 })
    stop()
  })

  it('stops reporting after cancel', async () => {
    bridge.calls = []
    document.body.innerHTML = '<div id="hole"></div>'
    const element = document.getElementById('hole') as HTMLElement
    const stop = trackLayout(element)
    stop()
    const before = bridge.calls.length
    window.dispatchEvent(new Event('scroll'))
    await frame()
    expect(bridge.calls.length).toBe(before)
  })
})
