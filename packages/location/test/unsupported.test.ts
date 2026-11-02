import { describe, expect, it, vi } from 'vitest'

// callPlugin 在 plugin 用不了的平台回 undefined；網頁 API 必須回安全的預設值，不能變成 TypeError
vi.mock('@aqutter/aqutter', () => ({
  callPlugin: vi.fn(async () => undefined),
  isPluginSupported: vi.fn(() => false),
  onPluginEvent: vi.fn(() => () => {}),
}))

const { location } = await import('../src/index')

describe('location when the plugin cannot run here', () => {
  it('reports no services and no permission instead of throwing', async () => {
    expect(await location.capabilities()).toEqual({ serviceEnabled: false, permission: 'denied' })
    expect(await location.requestPermission()).toBe('denied')
  })

  it('has no position, and no watch to stop', async () => {
    expect(await location.getCurrentPosition()).toBeNull()
    expect(await location.watch(() => {})).toBeNull()
  })

  it('settings do nothing', async () => {
    await expect(location.openSettings('app')).resolves.toBeUndefined()
  })
})
