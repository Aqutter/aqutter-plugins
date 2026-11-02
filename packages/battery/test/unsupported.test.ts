import { describe, expect, it, vi } from 'vitest'

vi.mock('@aqutter/aqutter', () => ({
  callPlugin: vi.fn(async () => undefined),
  isPluginSupported: vi.fn(() => false),
  onPluginEvent: vi.fn(() => () => {}),
}))

const { battery } = await import('../src/index')

describe('battery when the plugin cannot run here', () => {
  it('has no level, an unknown state, and no save mode', async () => {
    expect(await battery.level()).toBeNull()
    expect(await battery.state()).toBe('unknown')
    expect(await battery.isInSaveMode()).toBe(false)
    expect(battery.isSupported()).toBe(false)
  })
})
