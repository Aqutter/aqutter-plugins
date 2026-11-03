# aqutter-plugin-file-manager

Aqutter plugin：`file-manager`。讓網頁在 App 自己的資料夾裡讀、寫與管理檔案。同一個 repo 同時是 npm 套件（網頁端 API）與 Dart 套件（Flutter 端）。

> **進度**：`sandbox`、`gallery`、`downloads` 與 Android 的 `granted` 已在 Android 實機驗證（Zenfone 8，release 建置）：資料夾授權、寫入、讀取、列出、搬移、遞迴刪除、重新啟動後不必重新授權、存到相簿、系統另存視窗。桌面（Windows、macOS、Linux）的 `granted` 只有 Windows 的單元測試。**iOS 的 `granted` 尚未實作**（`grant`、`grants`、`revoke` 回 `UNSUPPORTED_PLATFORM`），macOS 沙盒 App（Mac App Store）需要 bookmark 才能跨重新啟動保留授權，也尚未處理。

## 範圍

| 功能 | 做什麼 | 原生設定 | 狀態 |
|---|---|---|---|
| `sandbox` | App 自己的資料夾（文件、支援、快取、暫存）：列、讀、寫、複製、移動、刪除、建資料夾、查資訊 | 不需要 | 🟢 |
| `granted` | 使用者用選擇器授權的資料夾（桌面也可授權單一檔案），授權可持久保存 | 不需要 | 🟢 Android（實機驗證，只支援資料夾）、桌面（Windows 單元測試）／🚧 iOS |
| `pick` | 一次性挑選檔案（單選或多選、可過濾副檔名），選到的檔案以 `picked:<編號>` 唯讀存取，不進授權清單 | macOS 沙盒 App 需要 `com.apple.security.files.user-selected.read-only` entitlement | 🟢 單元測試／🚧 實機尚未驗證 |
| `gallery` | 存圖到相簿（Android、iOS），只收 PNG 與 JPEG | iOS 相簿說明文字；Android 9 以前寫入權限 | 🟢（未實機驗證） |
| `downloads` | 開啟系統的「另存」視窗，讓使用者選存放位置（iOS 是匯出） | 不需要 | 🟢（未實機驗證） |

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
| `app-documents:報表/a.pdf` | App 的文件資料夾（桌面平台是 App 支援資料夾底下的 `documents`，**不是**使用者的「文件」資料夾） |
| `app-support:` | App 的支援資料夾（根本身） |
| `app-cache:`、`app-temp:` | 快取與暫存，系統可能清除（桌面的暫存是快取資料夾底下的 `temp`，不是系統共用暫存） |
| `granted:<授權編號>/子/路徑` | 使用者授權的位置（`granted` 功能） |
| `picked:<編號>` | 使用者一次性挑選的單一檔案（`pick`），只能讀，App 重啟後失效 |

相對路徑以 `/` 分段，不得有 `.`、`..`、空段、反斜線或控制字元；每段 ≤ 255、總長 ≤ 1024。解析符號連結後必須仍在根之內。

**Android 的授權只支援 `directory`**（系統的單一檔案授權無法持久保存，`file`、`files` 回 `UNSUPPORTED_PLATFORM`）；撤銷只刪除這個 plugin 的紀錄，Android 系統層保留的授權在清除 App 資料前仍存在（Android 對每個 App 可持久授權的數量有上限）。

資料夾授權用 `granted:<id>/子/路徑`，單一檔案授權（桌面）用 `granted:<id>`（沒有子路徑，只能讀、覆寫或刪除那個檔案，不能複製或搬移）。授權清單存在 `shared_preferences`，不在 App 資料夾裡，網頁無法竄改。

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
| `pick(kind, { extensions?, title? })` | `kind`：`file`（單選）、`files`（多選）。開啟系統選擇器，回傳 `[{ location, name, size? }]`；取消回空陣列。`location` 是 `picked:<編號>`：**只能讀**（`stat`、`read`、`copy` 的來源、`saveToDownloads` 的 `from`），其他操作回 `permission_denied`；編號只在本次 App 執行期間有效（失效回 `not_found`），不進 `grants()`。Android 選到的是 `file_picker` 複製進 App 快取的檔案，桌面是原檔。要長期保留請 `copy` 到 `app-documents:` 等位置。`kind` 或 `extensions` 不合法回 `invalid_argument` |
| `grant(kind)` | `kind`：`file`、`files`（多選，每個檔案各一個授權）、`directory`。開啟系統選擇器，回傳 `[{ id, name, kind }]`；取消回空陣列；重複選同一個位置沿用原來的編號。網頁拿不到實際路徑 |
| `grants()`、`revoke(id)` | 列出授權；撤銷只刪除紀錄、不動實際檔案。位置已不存在的授權仍會列出，操作時回 `permission_denied` |
| `saveToGallery(data, name, mimeType)` | 存圖到相簿（Android、iOS）；`mimeType` 為 `image/png` 或 `image/jpeg`，位元組開頭須相符；權限被拒回 `permission_denied` |

| `saveToDownloads({ data } \| { from }, name, mimeType)` | 開啟系統另存視窗；`data` ≤ 5 MiB，或用 `from`（App 資料夾的檔案，不經 bridge，上限 50 MiB）。回傳 `saved`、`exported`（iOS）或 `cancelled`（使用者取消，不算失敗） |

失敗時拋出 `AqutterPluginError`，`code` 為：`invalid_argument`、`invalid_path`、`not_found`、`already_exists`、`not_a_directory`、`is_a_directory`、`not_empty`、`too_large`、`permission_denied`、`cross_root_unsupported`。

## 開發

```bash
pnpm install
pnpm typecheck
flutter pub get
flutter test
```

契約與計畫見 `.kn-project/plans/`。
