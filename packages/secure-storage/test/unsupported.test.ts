import { describe, expect, it, vi } from 'vitest'

vi.mock('@aqutter/aqutter', () => ({
  callPlugin: vi.fn(async () => undefined),
  isPluginSupported: vi.fn(() => false),
  onPluginEvent: vi.fn(() => () => {}),
}))

const { secureStorage } = await import('../src/index')

describe('secureStorage when the plugin cannot run here', () => {
  it('reads come back empty instead of throwing', async () => {
    expect(await secureStorage.get('token')).toBeNull()
    expect(await secureStorage.has('token')).toBe(false)
    expect(await secureStorage.keys()).toEqual([])
  })

  it('reports no authentication support, so callers do not offer requireAuth', async () => {
    expect(await secureStorage.capabilities()).toEqual({ auth: false, biometrics: false })
  })

  it('writes do nothing and do not throw', async () => {
    await expect(secureStorage.set('token', 'x')).resolves.toBeUndefined()
    await expect(secureStorage.delete('token')).resolves.toBeUndefined()
    await expect(secureStorage.clear()).resolves.toBeUndefined()
  })
})
