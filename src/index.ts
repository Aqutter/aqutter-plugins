import { callPlugin } from '@aqutter/aqutter'
import type { PluginDefinition } from '@aqutter/aqutter'

/** 位置字串：`app-documents:報表/a.pdf`、`app-support:`、`app-cache:`、`app-temp:`、`granted:<授權編號>/子/路徑`。 */
export type FileLocation = string

export interface FileEntry {
  name: string
  kind: 'file' | 'directory'
  /** 資料夾沒有大小。 */
  size?: number
  /** Unix 毫秒。 */
  modified: number
}

export type WriteMode = 'create' | 'overwrite' | 'append'

/** 單次讀寫的內容上限（位元組）；更大的檔案用 `offset`／`length` 與 `append` 分段。 */
export const MAX_CONTENT_BYTES = 5 * 1024 * 1024

/** 此 plugin 的契約：方法表。Dart 端 `FileManagerPlugin` 必須提供同名方法（契約 rev 1）。 */
export type FileManagerContract = PluginDefinition<
  {
    list: { req: { location: FileLocation }, res: { entries: FileEntry[] } }
    stat: { req: { location: FileLocation }, res: { exists: boolean, kind?: 'file' | 'directory', size?: number, modified?: number } }
    read: { req: { location: FileLocation, offset?: number, length?: number }, res: { data: Uint8Array, eof: boolean } }
    write: { req: { location: FileLocation, data: Uint8Array, mode: WriteMode }, res: { size: number } }
    makeDirectory: { req: { location: FileLocation, recursive?: boolean }, res: Record<string, never> }
    copy: { req: { from: FileLocation, to: FileLocation, overwrite?: boolean }, res: Record<string, never> }
    move: { req: { from: FileLocation, to: FileLocation, overwrite?: boolean }, res: Record<string, never> }
    delete: { req: { location: FileLocation, recursive?: boolean }, res: Record<string, never> }
  },
  Record<string, never>
>

// 把契約併入全域 plugin 表：使用端即可用 callPlugin('file-manager', …) 得到完整型別
declare module '@aqutter/aqutter' {
  interface AqutterPluginRegistry {
    'file-manager': FileManagerContract
  }
}

/**
 * 網頁端 API。失敗時 `callPlugin` 拋出 `AqutterPluginError`，其 `code` 是契約的錯誤碼
 * （`invalid_path`、`not_found`、`already_exists`、`not_a_directory`、`is_a_directory`、`not_empty`、
 * `too_large`、`permission_denied`、`cross_root_unsupported`）。
 */
export const fileManager = {
  list: async (location: FileLocation): Promise<FileEntry[]> => (await callPlugin('file-manager', 'list', { location })).entries,
  stat: (location: FileLocation) => callPlugin('file-manager', 'stat', { location }),
  /** 讀取 `offset` 起至多 `length` 位元組（預設與上限 {@link MAX_CONTENT_BYTES}）；`eof` 為 true 代表已讀到檔尾。 */
  read: (location: FileLocation, options: { offset?: number, length?: number } = {}) =>
    callPlugin('file-manager', 'read', { location, ...options }),
  /** 回傳寫入後的檔案大小。 */
  write: async (location: FileLocation, data: Uint8Array, mode: WriteMode = 'create'): Promise<number> =>
    (await callPlugin('file-manager', 'write', { location, data, mode })).size,
  makeDirectory: async (location: FileLocation, options: { recursive?: boolean } = {}): Promise<void> => {
    await callPlugin('file-manager', 'makeDirectory', { location, ...options })
  },
  copy: async (from: FileLocation, to: FileLocation, options: { overwrite?: boolean } = {}): Promise<void> => {
    await callPlugin('file-manager', 'copy', { from, to, ...options })
  },
  move: async (from: FileLocation, to: FileLocation, options: { overwrite?: boolean } = {}): Promise<void> => {
    await callPlugin('file-manager', 'move', { from, to, ...options })
  },
  delete: async (location: FileLocation, options: { recursive?: boolean } = {}): Promise<void> => {
    await callPlugin('file-manager', 'delete', { location, ...options })
  },
}
