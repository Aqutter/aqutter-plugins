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

const { forwardGestures } = await import('../src/nativeProvider')
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
    element.getBoundingClientRect = () => ({ left: 0, top: 0, width: 200, height: 100, right: 200, bottom: 100, x: 0, y: 0, toJSON: () => ({}) })
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
    document.body.innerHTML = '<div id="box"></div>'
    const view = await googleMaps.mount(document.getElementById('box') as HTMLElement)
    expect(document.querySelector('aqutter-native')).toBeNull()
    expect(document.querySelector('#box > div')).not.toBeNull()
    view.destroy()
    expect(document.querySelector('#box > div')).toBeNull()
  })

  it('keeps aqutter-native when the plugin is not in passthrough mode', async () => {
    bridge.passthrough = false
    document.body.innerHTML = '<div id="box"></div>'
    const view = await googleMaps.mount(document.getElementById('box') as HTMLElement)
    expect(document.querySelector('aqutter-native')).not.toBeNull()
    view.destroy()
  })
})
