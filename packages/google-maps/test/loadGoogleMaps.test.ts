// @vitest-environment happy-dom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { LOAD_TIMEOUT_MS, loadGoogleMaps, resetGoogleMapsLoader, scriptUrl } from '../src/loadGoogleMaps'

type TestWindow = Window & { google?: unknown, __aqutterGoogleMapsReady?: () => void }
const testWindow = (): TestWindow => window as unknown as TestWindow

const scripts = (): HTMLScriptElement[] => [...document.head.querySelectorAll('script')]

describe('loadGoogleMaps', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    resetGoogleMapsLoader()
    delete testWindow().google
    document.head.innerHTML = ''
  })
  afterEach(() => {
    vi.useRealTimers()
  })

  it('builds the script url with the key and the callback', () => {
    expect(scriptUrl('K 1')).toBe('https://maps.googleapis.com/maps/api/js?key=K%201&callback=__aqutterGoogleMapsReady&v=weekly')
  })

  it('resolves immediately when google.maps already exists', async () => {
    const maps = { Map: class {} }
    testWindow().google = { maps }
    await expect(loadGoogleMaps('k')).resolves.toBe(maps)
    expect(scripts()).toHaveLength(0)
  })

  it('inserts one script and resolves when the callback fires', async () => {
    const promise = loadGoogleMaps('k')
    expect(scripts()).toHaveLength(1)
    expect(scripts()[0]?.src).toContain('key=k')
    const maps = { Map: class {} }
    testWindow().google = { maps }
    testWindow().__aqutterGoogleMapsReady?.()
    await expect(promise).resolves.toBe(maps)
  })

  it('shares the pending load between concurrent calls with the same key', () => {
    const first = loadGoogleMaps('k')
    const second = loadGoogleMaps('k')
    expect(second).toBe(first)
    expect(scripts()).toHaveLength(1)
    first.catch(() => {})
  })

  it('rejects when the script fails to load, and can be retried', async () => {
    const promise = loadGoogleMaps('k')
    const assertion = expect(promise).rejects.toThrow(/failed to load/)
    scripts()[0]?.onerror?.(new Event('error') as never)
    await assertion
    const retry = loadGoogleMaps('k')
    expect(retry).not.toBe(promise)
    expect(scripts()).toHaveLength(1)
    retry.catch(() => {})
  })

  it('rejects instead of hanging when the load times out', async () => {
    const promise = loadGoogleMaps('k', 1000)
    const assertion = expect(promise).rejects.toThrow(/timed out after 1000 ms/)
    await vi.advanceTimersByTimeAsync(1000)
    await assertion
  })

  it('rejects when the script loads but google.maps is missing', async () => {
    const promise = loadGoogleMaps('k')
    const assertion = expect(promise).rejects.toThrow(/google\.maps is missing/)
    testWindow().__aqutterGoogleMapsReady?.()
    await assertion
  })

  it('uses a 15 second default timeout', () => {
    expect(LOAD_TIMEOUT_MS).toBe(15_000)
  })
})
