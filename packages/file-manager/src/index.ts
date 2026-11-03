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

/** 使用者授權的位置；用 `granted:<id>/相對路徑` 操作。網頁看不到實際路徑。 */
export interface FileGrant {
  id: string
  name: string
  kind: 'file' | 'directory'
}

/** 一次性選取的檔案；`location` 是 `picked:<編號>`，只能讀，App 重啟後失效。網頁看不到實際路徑。 */
export interface PickedFile {
  location: FileLocation
  name: string
  /** 位元組；取不到時省略。 */
  size?: number
}

export type WriteMode ='create' | 'overwrite' | 'append'

/** 單次讀寫的內容上限（位元組）；更大的檔案用 `offset`／`length` 與 `append` 分段。 */
export const MAX_CONTENT_BYTES = 5 * 1024 * 1024

/** 此 plugin 的契約：方法表。Dart 端 `FileManagerPlugin` 必須提供同名方法（契約 rev 1）。`pick` 與 `picked:` 位置是後來新增的，不影響既有方法。 */
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
    pick: { req: { kind: 'file' | 'files', extensions?: string[], title?: string }, res: { items: PickedFile[] } }
    grant: { req: { kind: 'file' | 'files' | 'directory' }, res: { grants: FileGrant[] } }
    grants: { req: Record<string, never>, res: { grants: FileGrant[] } }
    revoke: { req: { id: string }, res: Record<string, never> }
    saveToGallery: { req: { data: Uint8Array, name: string, mimeType: 'image/png' | 'image/jpeg' }, res: { status: 'saved' } }
    saveToDownloads: {
      req: { name: string, mimeType: string } & ({ data: Uint8Array, from?: never } | { from: FileLocation, data?: never })
      res: { status: 'saved' | 'exported' | 'cancelled' }
    }
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
 * 網頁端 API。**plugin 在這個平台用不了時不拋錯**（`callPlugin` 回 `undefined`），各方法回安全的預設值：
 * `list`／`pick`／`grant`／`grants` 回 `[]`、`stat` 回 `{ exists: false }`、`read` 回空內容且 `eof`、`write` 回 0、
 * `saveToDownloads` 回 `cancelled`，其餘不做事。要事先判斷用 `isPluginSupported('file-manager', <方法>)`。
 *
 * 失敗時 `callPlugin` 拋出 `AqutterPluginError`，其 `code` 是契約的錯誤碼
 * （`invalid_path`、`not_found`、`already_exists`、`not_a_directory`、`is_a_directory`、`not_empty`、
 * `too_large`、`permission_denied`、`cross_root_unsupported`）。
 */
export const fileManager = {
  list: async (location: FileLocation): Promise<FileEntry[]> => (await callPlugin('file-manager', 'list', { location }))?.entries ?? [],
  stat: async (location: FileLocation) => (await callPlugin('file-manager', 'stat', { location })) ?? { exists: false as boolean },
  /** 讀取 `offset` 起至多 `length` 位元組（預設與上限 {@link MAX_CONTENT_BYTES}）；`eof` 為 true 代表已讀到檔尾。 */
  read: async (location: FileLocation, options: { offset?: number, length?: number } = {}) =>
    (await callPlugin('file-manager', 'read', { location, ...options })) ?? { data: new Uint8Array(0), eof: true },
  /** 回傳寫入後的檔案大小。 */
  write: async (location: FileLocation, data: Uint8Array, mode: WriteMode = 'create'): Promise<number> =>
    (await callPlugin('file-manager', 'write', { location, data, mode }))?.size ?? 0,
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
  /**
   * 開啟系統的選擇器，讓使用者**一次性**挑選檔案：`file` 選一個、`files` 選多個，可用 `extensions`（不含點，如 `['pdf']`）過濾。
   * 取消回空陣列。回傳的 `location` 是 `picked:<編號>`，只能讀（`stat`、`read`、`copy` 的來源、`saveToDownloads` 的 `from`），
   * 不會進授權清單，App 重啟後失效；要長期使用請 `copy` 到 `app-documents:` 等位置，或改用 {@link fileManager.grant}。
   * Android 選到的是複製進 App 快取的檔案，其他平台是原檔。
   */
  pick: async (kind: 'file' | 'files', options: { extensions?: string[], title?: string } = {}): Promise<PickedFile[]> =>
    (await callPlugin('file-manager', 'pick', { kind, ...options }))?.items ?? [],
  /**
   * 開啟系統的選擇器，讓使用者授權檔案或資料夾；`files` 為一次選多個檔案（每個檔案各一個授權）。
   * 取消回空陣列。授權會持久保存；資料夾授權用 `granted:<id>/子/路徑`，單一檔案授權用 `granted:<id>`（沒有子路徑）。
   * 目前只有桌面平台（Windows、macOS、Linux）。
   */
  grant: async (kind: 'file' | 'files' | 'directory'): Promise<FileGrant[]> => (await callPlugin('file-manager', 'grant', { kind }))?.grants ?? [],
  /** 目前所有授權；實際位置已不存在的授權仍會列出，操作時回 `permission_denied`。 */
  grants: async (): Promise<FileGrant[]> => (await callPlugin('file-manager', 'grants', {}))?.grants ?? [],
  /** 撤銷授權；只刪除授權紀錄，不會動到實際的檔案。 */
  revoke: async (id: string): Promise<void> => {
    await callPlugin('file-manager', 'revoke', { id })
  },
  /** 存圖到相簿（Android、iOS）。只收 PNG 與 JPEG，位元組開頭必須與 `mimeType` 相符，單次上限 {@link MAX_CONTENT_BYTES}。 */
  saveToGallery: async (data: Uint8Array, name: string, mimeType: 'image/png' | 'image/jpeg'): Promise<void> => {
    await callPlugin('file-manager', 'saveToGallery', { data, name, mimeType })
  },
  /**
   * 開啟系統的「另存」視窗，讓使用者選存放位置（不需要權限）。內容二擇一：`data`（≤ {@link MAX_CONTENT_BYTES}），
   * 或 `from`（App 資料夾或授權位置的檔案，不經 bridge，上限 50 MiB）。
   * 回傳 `saved`（已存下）、`exported`（iOS 的匯出）或 `cancelled`（使用者取消，不算失敗）。
   */
  saveToDownloads: async (
    content: { data: Uint8Array } | { from: FileLocation },
    name: string,
    mimeType: string,
  ): Promise<'saved' | 'exported' | 'cancelled'> => {
    const request = 'data' in content ? { name, mimeType, data: content.data } : { name, mimeType, from: content.from }
    return (await callPlugin('file-manager', 'saveToDownloads', request))?.status ?? 'cancelled'
  },
}
