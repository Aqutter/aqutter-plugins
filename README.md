# aqutter-plugin-file-manager

Aqutter plugin：`file-manager`。讓網頁在 App 自己的資料夾裡讀、寫與管理檔案。同一個 repo 同時是 npm 套件（網頁端 API）與 Dart 套件（Flutter 端）。

> **進度**：`sandbox`（App 資料夾）與 `gallery`（存到相簿）的 Dart 端與網頁端已完成，尚未在實機驗證；`granted`（使用者授權的位置）、`downloads`（存到下載）尚未實作，對應的方法還不存在（`isPluginSupported` 為 false）。

## 範圍

| 功能 | 做什麼 | 原生設定 | 狀態 |
|---|---|---|---|
| `sandbox` | App 自己的資料夾（文件、支援、快取、暫存）：列、讀、寫、複製、移動、刪除、建資料夾、查資訊 | 不需要 | 🟢 |
| `granted` | 使用者用選擇器授權的檔案或資料夾，授權可持久保存 | 不需要 | 🚧 |
| `gallery` | 存圖到相簿（Android、iOS），只收 PNG 與 JPEG | iOS 相簿說明文字；Android 9 以前寫入權限 | 🟢（未實機驗證） |
| `downloads` | 存檔到下載（iOS 用系統的匯出視窗） | Android 9 以前寫入權限 | 🚧 |

**刻意不做**：

- 整機檔案存取：Android 的 `MANAGE_EXTERNAL_STORAGE` 是 Google Play 的受限權限，iOS 沒有等價物。
- 目錄監聽。
- 跨根的複製與搬移（請用讀加寫）。

## 安裝

```bash
aqutter plugin add aqutter-plugin-file-manager                       # 全部功能
aqutter plugin add aqutter-plugin-file-manager --features sandbox    # 只用 App 資料夾，不需要補任何原生設定
```

## 位置字串

網頁不碰各平台不同的路徑，一律用「根＋相對路徑」：

| 位置 | 說明 |
|---|---|
| `app-documents:報表/a.pdf` | App 的文件資料夾 |
| `app-support:` | App 的支援資料夾（根本身） |
| `app-cache:`、`app-temp:` | 快取與暫存，系統可能清除 |
| `granted:<授權編號>/子/路徑` | 使用者授權的位置（`granted` 功能） |

相對路徑以 `/` 分段，不得有 `.`、`..`、空段、反斜線或控制字元；每段 ≤ 255、總長 ≤ 1024。解析符號連結後必須仍在根之內。

## 網頁端

```ts
import { fileManager } from 'aqutter-plugin-file-manager'

await fileManager.makeDirectory('app-documents:報表', { recursive: true })
await fileManager.write('app-documents:報表/a.txt', new TextEncoder().encode('hello'), 'create')

const { data, eof } = await fileManager.read('app-documents:報表/a.txt')
const entries = await fileManager.list('app-documents:報表')   // [{ name, kind, size?, modified }]

await fileManager.move('app-documents:報表/a.txt', 'app-documents:報表/b.txt')
await fileManager.delete('app-documents:報表', { recursive: true })
```

| 方法 | 說明 |
|---|---|
| `list(location)` | 列出資料夾，依名稱排序 |
| `stat(location)` | `{ exists, kind?, size?, modified? }`；不存在不會失敗 |
| `read(location, { offset?, length? })` | 單次上限 5 MiB；`eof` 為 true 代表讀到檔尾，更大的檔案分段讀 |
| `write(location, data, mode)` | `mode`：`create`（已存在失敗）、`overwrite`、`append`；單次上限 5 MiB，更大的檔案用 `append` 分段寫 |
| `makeDirectory(location, { recursive? })` | 建資料夾 |
| `copy(from, to, { overwrite? })`、`move(...)` | 檔案與整個資料夾；兩端必須在同一個根 |
| `delete(location, { recursive? })` | 非空資料夾要 `recursive`；根本身不能刪 |
| `saveToGallery(data, name, mimeType)` | 存圖到相簿（Android、iOS）；`mimeType` 為 `image/png` 或 `image/jpeg`，位元組開頭須相符；權限被拒回 `permission_denied` |

失敗時拋出 `AqutterPluginError`，`code` 為：`invalid_path`、`not_found`、`already_exists`、`not_a_directory`、`is_a_directory`、`not_empty`、`too_large`、`permission_denied`、`cross_root_unsupported`。

## 開發

```bash
pnpm install
pnpm typecheck
flutter pub get
flutter test
```

契約與計畫見 `.kn-project/plans/`。
