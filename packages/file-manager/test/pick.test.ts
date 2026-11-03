import { describe, expect, it, vi } from 'vitest'

const callPlugin = vi.fn(async (..._args: unknown[]) => ({ items: [{ location: 'picked:abc', name: 'a.pdf', size: 3 }] }))
vi.mock('@aqutter/aqutter', () => ({
  callPlugin: (...args: unknown[]) => callPlugin(...args),
  isPluginSupported: vi.fn(() => true),
  onPluginEvent: vi.fn(() => () => {}),
}))

const { fileManager } = await import('../src/index')

describe('fileManager.pick', () => {
  it('passes the kind and options through and returns the items', async () => {
    const items = await fileManager.pick('files', { extensions: ['pdf'], title: 'Reports' })

    expect(callPlugin).toHaveBeenCalledWith('file-manager', 'pick', { kind: 'files', extensions: ['pdf'], title: 'Reports' })
    expect(items).toEqual([{ location: 'picked:abc', name: 'a.pdf', size: 3 }])
  })

  it('works without options', async () => {
    await fileManager.pick('file')

    expect(callPlugin).toHaveBeenLastCalledWith('file-manager', 'pick', { kind: 'file' })
  })
})
