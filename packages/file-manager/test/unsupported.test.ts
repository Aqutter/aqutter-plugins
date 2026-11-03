import { describe, expect, it, vi } from 'vitest'

// callPlugin 在 plugin 用不了的平台回 undefined；網頁 API 必須回安全的預設值，不能變成 TypeError
vi.mock('@aqutter/aqutter', () => ({
  callPlugin: vi.fn(async () => undefined),
  isPluginSupported: vi.fn(() => false),
  onPluginEvent: vi.fn(() => () => {}),
}))

const { fileManager } = await import('../src/index')

describe('fileManager when the plugin cannot run here', () => {
  it('reads come back empty instead of throwing', async () => {
    expect(await fileManager.list('app-documents:')).toEqual([])
    expect(await fileManager.stat('app-documents:a')).toEqual({ exists: false })
    const read = await fileManager.read('app-documents:a')
    expect(read.data).toEqual(new Uint8Array(0))
    expect(read.eof).toBe(true)
    expect(await fileManager.grants()).toEqual([])
    expect(await fileManager.grant('directory')).toEqual([])
    expect(await fileManager.pick('file', { extensions: ['pdf'] })).toEqual([])
  })

  it('writes do nothing and report nothing was saved', async () => {
    expect(await fileManager.write('app-documents:a', new Uint8Array([1]))).toBe(0)
    expect(await fileManager.saveToDownloads({ data: new Uint8Array([1]) }, 'a.txt', 'text/plain')).toBe('cancelled')
    await expect(fileManager.makeDirectory('app-documents:d')).resolves.toBeUndefined()
    await expect(fileManager.delete('app-documents:d')).resolves.toBeUndefined()
    await expect(fileManager.saveToGallery(new Uint8Array([1]), 'a.png', 'image/png')).resolves.toBeUndefined()
  })
})
