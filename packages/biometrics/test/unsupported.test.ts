import { describe, expect, it, vi } from 'vitest'

// callPlugin 在 plugin 用不了的平台回 undefined；網頁 API 必須回安全的預設值，不能變成 TypeError
vi.mock('@aqutter/aqutter', () => ({
  callPlugin: vi.fn(async () => undefined),
  isPluginSupported: vi.fn(() => false),
  onPluginEvent: vi.fn(() => () => {}),
}))

const { biometrics } = await import('../src/index')

describe('biometrics when the plugin cannot run here', () => {
  it('says no way to authenticate instead of throwing', async () => {
    expect(await biometrics.capabilities()).toEqual({ available: false, biometrics: false, types: [] })
    expect(await biometrics.authenticate({ reason: 'confirm' })).toBe('unavailable')
  })
})
