// @vitest-environment happy-dom
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { resetGoogleMapsLoader } from '../src/loadGoogleMaps'
import { createJsView } from '../src/jsProvider'

type Handler = (event?: unknown) => void

class FakeMap {
  static last: FakeMap | undefined
  center = { lat: 1, lng: 2 }
  zoom = 5
  mapTypeId = 'roadmap'
  handlers = new Map<string, Handler>()
  panned: { lat: number, lng: number }[] = []
  removed: string[] = []

  constructor(public element: HTMLElement, public options: Record<string, unknown>) {
    FakeMap.last = this
    const center = options.center as { lat: number, lng: number }
    this.center = center
    this.zoom = options.zoom as number
    this.mapTypeId = options.mapTypeId as string
  }

  getCenter() {
    return { lat: () => this.center.lat, lng: () => this.center.lng }
  }

  getZoom() {
    return this.zoom
  }

  setCenter(position: { lat: number, lng: number }) {
    this.center = position
  }

  panTo(position: { lat: number, lng: number }) {
    this.panned.push(position)
    this.center = position
  }

  setZoom(zoom: number) {
    this.zoom = zoom
  }

  setMapTypeId(id: string) {
    this.mapTypeId = id
  }

  addListener(name: string, handler: Handler) {
    this.handlers.set(name, handler)
    return { remove: () => this.removed.push(name) }
  }
}

class FakeMarker {
  static all: FakeMarker[] = []
  map: FakeMap | null
  constructor(public options: { map: FakeMap, position: { lat: number, lng: number }, title?: string }) {
    this.map = options.map
    FakeMarker.all.push(this)
  }

  setMap(map: FakeMap | null) {
    this.map = map
  }
}

describe('createJsView', () => {
  beforeEach(() => {
    vi.useRealTimers()
    resetGoogleMapsLoader()
    FakeMarker.all = []
    FakeMap.last = undefined
    document.body.innerHTML = '<div id="box"></div>'
    ;(window as unknown as { google: unknown }).google = { maps: { Map: FakeMap, Marker: FakeMarker } }
  })

  const mount = async (options = {}) => {
    const container = document.getElementById('box') as HTMLElement
    const view = await createJsView(container, options, 'key')
    return { container, view, map: FakeMap.last as FakeMap }
  }

  it('creates the map inside the container with the requested camera and type', async () => {
    const { container, map, view } = await mount({ camera: { lat: 35, lng: 139, zoom: 11 }, mapType: 'satellite' })
    expect(view.provider).toBe('js')
    expect(container.contains(map.element)).toBe(true)
    expect(map.options.center).toEqual({ lat: 35, lng: 139 })
    expect(map.zoom).toBe(11)
    expect(map.mapTypeId).toBe('satellite')
  })

  it('lets the caller overlay other HTML in the container', async () => {
    const { container } = await mount()
    const hud = document.createElement('div')
    container.append(hud)
    expect(container.children).toHaveLength(2)
  })

  it('moves the camera immediately by default and pans when animate is true', async () => {
    const { map, view } = await mount()
    await view.moveTo(10, 20, { zoom: 8 })
    expect(map.center).toEqual({ lat: 10, lng: 20 })
    expect(map.zoom).toBe(8)
    expect(map.panned).toEqual([])
    await view.moveTo(11, 21, { animate: true })
    expect(map.panned).toEqual([{ lat: 11, lng: 21 }])
    await expect(view.getCamera()).resolves.toEqual({ lat: 11, lng: 21, zoom: 8 })
  })

  it('replaces all markers with the given list', async () => {
    const { view } = await mount()
    await view.setMarkers([{ lat: 1, lng: 1, title: 'a' }, { lat: 2, lng: 2 }])
    expect(FakeMarker.all.filter(marker => marker.map)).toHaveLength(2)
    await view.setMarkers([{ lat: 3, lng: 3 }])
    expect(FakeMarker.all.filter(marker => marker.map)).toHaveLength(1)
    expect(FakeMarker.all.at(-1)?.options.position).toEqual({ lat: 3, lng: 3 })
  })

  it('maps the map types onto Google map type ids', async () => {
    const { map, view } = await mount()
    for (const [type, id] of [['normal', 'roadmap'], ['terrain', 'terrain'], ['hybrid', 'hybrid']] as const) {
      await view.setMapType(type)
      expect(map.mapTypeId).toBe(id)
    }
  })

  it('reports ready once, after the caller has subscribed', async () => {
    const { view } = await mount()
    const ready = vi.fn()
    view.onReady(ready)
    await new Promise(resolve => setTimeout(resolve, 5))
    expect(ready).toHaveBeenCalledTimes(1)
    expect(ready).toHaveBeenCalledWith({ lat: 0, lng: 0, zoom: 2 })
  })

  it('forwards idle and click events and supports unsubscribing', async () => {
    const { map, view } = await mount({ camera: { lat: 5, lng: 6, zoom: 4 } })
    const idle = vi.fn()
    const tap = vi.fn()
    const stopIdle = view.onCameraIdle(idle)
    view.onTap(tap)
    map.handlers.get('idle')?.()
    expect(idle).toHaveBeenCalledWith({ lat: 5, lng: 6, zoom: 4 })
    map.handlers.get('click')?.({ latLng: { lat: () => 7, lng: () => 8 } })
    expect(tap).toHaveBeenCalledWith({ lat: 7, lng: 8 })
    map.handlers.get('click')?.({})
    expect(tap).toHaveBeenCalledTimes(1)
    stopIdle()
    map.handlers.get('idle')?.()
    expect(idle).toHaveBeenCalledTimes(1)
  })

  it('removes the map, listeners and markers on destroy', async () => {
    const { container, map, view } = await mount()
    await view.setMarkers([{ lat: 1, lng: 1 }])
    const tap = vi.fn()
    view.onTap(tap)
    view.destroy()
    expect(container.contains(map.element)).toBe(false)
    expect(map.removed.sort()).toEqual(['click', 'idle'])
    expect(FakeMarker.all.every(marker => marker.map === null)).toBe(true)
  })
})
