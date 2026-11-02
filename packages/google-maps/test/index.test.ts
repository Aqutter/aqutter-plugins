// @vitest-environment happy-dom
import { beforeEach, describe, expect, it, vi } from 'vitest'

const bridge = vi.hoisted(() => ({
  supported: true,
  calls: [] as { method: string, payload?: unknown }[],
  listeners: new Map<string, (payload: unknown) => void>(),
  unsubscribed: [] as string[],
}))

vi.mock('@aqutter/aqutter', () => ({
  defineAqutterNative: () => {},
  isPluginSupported: () => bridge.supported,
  callPlugin: async (_id: string, method: string, payload?: unknown) => {
    bridge.calls.push({ method, payload })
    return method === 'getCamera' ? { lat: 1, lng: 2, zoom: 3 } : { ok: true }
  },
  onPluginEvent: (_id: string, event: string, listener: (payload: unknown) => void) => {
    bridge.listeners.set(event, listener)
    return () => {
      bridge.unsubscribed.push(event)
    }
  },
}))

const { googleMaps } = await import('../src/index')

describe('googleMaps', () => {
  beforeEach(() => {
    bridge.supported = true
    bridge.calls = []
    bridge.listeners.clear()
    bridge.unsubscribed = []
    document.body.innerHTML = '<div id="box"></div>'
    googleMaps.configure({ jsApiKey: undefined })
    delete (window as unknown as { google?: unknown }).google
  })

  const box = (): HTMLElement => document.getElementById('box') as HTMLElement

  it('picks the native provider when the shell reports native support, otherwise js', () => {
    expect(googleMaps.provider()).toBe('native')
    bridge.supported = false
    expect(googleMaps.provider()).toBe('js')
  })

  describe('native provider', () => {
    it('puts an <aqutter-native> for the google-maps session inside the container', async () => {
      const view = await googleMaps.mount(box())
      const element = box().querySelector('aqutter-native')
      expect(view.provider).toBe('native')
      expect(element?.getAttribute('session')).toBe('google-maps')
      expect(googleMaps.element(box())).toBe(element)
    })

    it('applies the initial map type and camera through the plugin', async () => {
      await googleMaps.mount(box(), { mapType: 'hybrid', camera: { lat: 35, lng: 139, zoom: 11 } })
      expect(bridge.calls).toEqual([
        { method: 'setMapType', payload: { type: 'hybrid' } },
        { method: 'moveTo', payload: { lat: 35, lng: 139, zoom: 11 } },
      ])
    })

    it('forwards the view methods to the plugin methods', async () => {
      const view = await googleMaps.mount(box())
      await view.moveTo(1, 2, { zoom: 5, animate: true })
      await view.setMarkers([{ lat: 1, lng: 2, title: 't' }])
      await view.setMapType('terrain')
      await expect(view.getCamera()).resolves.toEqual({ lat: 1, lng: 2, zoom: 3 })
      expect(bridge.calls).toEqual([
        { method: 'moveTo', payload: { lat: 1, lng: 2, zoom: 5, animate: true } },
        { method: 'setMarkers', payload: { markers: [{ lat: 1, lng: 2, title: 't' }] } },
        { method: 'setMapType', payload: { type: 'terrain' } },
        { method: 'getCamera', payload: undefined },
      ])
    })

    it('maps plugin events to the view listeners and unsubscribes on destroy', async () => {
      const view = await googleMaps.mount(box())
      const ready = vi.fn()
      const tap = vi.fn()
      view.onReady(ready)
      view.onTap(tap)
      bridge.listeners.get('ready')?.({ camera: { lat: 1, lng: 2, zoom: 3 } })
      bridge.listeners.get('tap')?.({ lat: 4, lng: 5 })
      expect(ready).toHaveBeenCalledWith({ lat: 1, lng: 2, zoom: 3 })
      expect(tap).toHaveBeenCalledWith({ lat: 4, lng: 5 })
      view.destroy()
      expect(bridge.unsubscribed.sort()).toEqual(['ready', 'tap'])
      expect(box().querySelector('aqutter-native')).toBeNull()
    })
  })

  describe('js provider', () => {
    beforeEach(() => {
      bridge.supported = false
    })

    it('rejects with a hint to call configure when no key was given', async () => {
      await expect(googleMaps.mount(box())).rejects.toThrow(/googleMaps\.configure\(\{ jsApiKey \}\)/)
    })

    it('mounts through the Google Maps JavaScript API once a key is configured', async () => {
      class FakeMap {
        constructor(public element: HTMLElement) {}
        getCenter() {
          return { lat: () => 0, lng: () => 0 }
        }

        getZoom() {
          return 2
        }

        addListener() {
          return { remove: () => {} }
        }
      }
      ;(window as unknown as { google: unknown }).google = { maps: { Map: FakeMap, Marker: class {} } }
      googleMaps.configure({ jsApiKey: 'abc' })
      const view = await googleMaps.mount(box())
      expect(view.provider).toBe('js')
      expect(bridge.calls).toEqual([])
    })
  })
})
