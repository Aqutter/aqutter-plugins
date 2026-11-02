# Plan: 2611021300 - file-manager-plugin
- Created: 2026-11-02
- Branch: N/A（直接 main）
- Issue: N/A（無 issue 追蹤基準）
- Milestone: N/A（未指定）
- Base Branch: main
- Status: In Progress
- Completed: [Wait for Finish]

## Goals
提供官方外部 plugin `file-manager`：讓網頁能在 App 自己的資料夾、使用者授權的位置、以及相簿與下載裡讀寫與管理檔案。網頁端原本只有「選檔案」（回傳路徑，讀不到內容），沒有讀取、寫出、列目錄、刪除，也不能存相簿或下載。範圍分三層：

1. **sandbox** — App 自己的資料夾（文件、支援、快取、暫存）：列、讀、寫、複製、移動、刪除、建資料夾、查資訊。
2. **granted** — 使用者用選擇器授權的檔案或資料夾：授權可持久保存，在授權範圍內讀、列、寫、刪除。
3. **gallery／downloads** — 存圖到相簿、存檔到下載。

使用者可以只選用部分功能（`plugin add --features`），只有 `gallery` 會要求使用者補原生設定（`downloads` 在 rev 2 改用系統視窗後也不需要）。

## Architecture
- 全新 repo `aqutter-plugin-file-manager`，由 `aqutter plugin create file-manager` 產生骨架。Dart 端 `FileManagerPlugin`（id `file-manager`），網頁端 `fileManager` API。
- **位置模型**：網頁不碰各平台不同的路徑或 URI，一律用「位置字串」：`app-documents:報表/a.pdf`、`app-support:`、`app-cache:`、`app-temp:`（根＋相對路徑）與 `granted:<授權編號>/相對路徑`。解析與驗證只在 Dart 層做。
- **路徑驗證**：相對路徑不得為空段以外的 `..`、不得為絕對路徑、不含反斜線與 NUL，每段 ≤ 255、總長 ≤ 1024；解析符號連結後必須仍在根之內（沿用殼對下載檔名的驗證精神）。
- **內容經過 bridge 的上限**：單次讀寫位元組 ≤ 5 MiB（與殼的剪貼簿圖片、分享一致），大檔案用 `offset`／`length` 與 `append` 分段。
- **授權（granted）**：Android 用 Storage Access Framework 的樹狀授權並 `takePersistableUriPermission`；iOS 用 security-scoped bookmark；授權清單由 plugin 持久化（支援目錄下的 JSON），撤銷或失效回 `permission_denied`。
- **相簿**：Android 10+ 走 MediaStore（不需權限），9 以前需寫入權限；iOS 走相簿新增 API。**下載**：四個平台都開系統的「另存」視窗（`file_picker.saveFile`），不需要權限；iOS 是匯出，結果回 `exported`（rev 2，原為 Android 走 MediaStore 靜默寫入）。
- **不做**：整機檔案存取（Android `MANAGE_EXTERNAL_STORAGE` 是 Google Play 受限權限；iOS 沒有等價物）、目錄監聽、跨根的搬移（跨根請用讀＋寫）。
- 平台（第一版）：Android、iOS 全功能；macOS、Windows 支援 `sandbox`、`granted`（以選擇器取得路徑直接存取，macOS 處理沙盒 bookmark）與 `downloads`；`gallery` 只有 Android、iOS，其餘回 `UNSUPPORTED_PLATFORM`（以 `supportedPlatformsFor` 逐方法宣告）。

## Cross-Repo Scope
- **本計畫所屬 repo**: `aqutter-plugin-file-manager`
- **共用計畫 ID**: 無（本 plugin 獨立 repo；使用方是各 App）
- **依賴**: `aqutter`（殼與 plugin 介面，需含 plugin 描述檔 `native` 宣告，已發佈）、`aqutter-cli`（`plugin add --features`、doctor 檢查，已發佈）。
- **執行順序相依**: 無；範例 App 的接入與展示另開計畫。
- **跨 repo 檔案指涉**: `aqutter` 的 `docs/plugins.md`「宣告原生設定」是描述檔 `native` 的契約。

## Contract / 介面契約
- **契約正本 repo**: `aqutter-plugin-file-manager`　**修訂號**: `rev 2`　**狀態**: `凍結（核准日 2026-11-02；rev 2 變更經使用者確認）`

### 1. 方法（`callPlugin('file-manager', <method>, payload)`；Dart 的 handler 名稱 `file-manager.<method>`）
| # | 方法 | 功能 | 請求 | 回應 |
|---|---|---|---|---|
| 1 | `list` | sandbox／granted | `{ location }` | `{ entries: { name, kind: 'file'\|'directory', size?, modified }[] }` |
| 2 | `stat` | sandbox／granted | `{ location }` | `{ exists, kind?, size?, modified? }` |
| 3 | `read` | sandbox／granted | `{ location, offset?, length? }` | `{ data: Uint8Array, eof }` |
| 4 | `write` | sandbox／granted | `{ location, data, mode }`，`mode` ∈ `create`\|`overwrite`\|`append` | `{ size }` |
| 5 | `makeDirectory` | sandbox／granted | `{ location, recursive? }` | `{}` |
| 6 | `copy` | sandbox／granted | `{ from, to, overwrite? }`（同一根內） | `{}` |
| 7 | `move` | sandbox／granted | `{ from, to, overwrite? }`（同一根內） | `{}` |
| 8 | `delete` | sandbox／granted | `{ location, recursive? }`；刪非空資料夾需 `recursive: true` | `{}` |
| 9 | `grant` | granted | `{ kind: 'file'\|'files'\|'directory', mimeTypes? }` | `{ grants: { id, name, kind }[] }`；取消回空陣列 |
| 10 | `grants` | granted | `{}` | `{ grants: { id, name, kind }[] }` |
| 11 | `revoke` | granted | `{ id }` | `{}` |
| 12 | `saveToGallery` | gallery | `{ data, name, mimeType }`，圖片 PNG／JPEG | `{ status: 'saved' }` |
| 13 | `saveToDownloads` | downloads | `{ name, mimeType, data? , from? }`（`data` 與 `from` 擇一；`from` 是 sandbox 或授權位置，可超過 5 MiB，上限 50 MiB） | `{ status: 'saved'\|'exported'\|'cancelled' }`；開啟系統的「另存」視窗，使用者選存放位置；iOS 回 `exported`，使用者取消回 `cancelled` |

### 2. 欄位與限制
| 項目 | 規則 |
|---|---|
| 位置字串 | `app-documents:`、`app-support:`、`app-cache:`、`app-temp:` 或 `granted:<id>`，後接 `/` 分隔的相對路徑；其餘格式一律 `invalid_path` |
| 單次內容 | `read` 的 `length` 預設與上限 5 MiB；`write` 的 `data` ≤ 5 MiB；超過回 `too_large` |
| `write` 模式 | `create`：已存在回 `already_exists`；`overwrite`：存在則取代；`append`：不存在則建立；父資料夾不存在回 `not_found` |
| 檔名（`saveTo*`） | 單一檔名，無路徑分隔、無控制字元、≤ 255；`mimeType` 必填且須與副檔名不衝突時才採用 |
| 時間 | `modified` 為 Unix 毫秒 |
| 序列化 | `Uint8Array` 以殼的二進位格式傳遞（見 `docs/plugins.md` 二進位一節） |

### 3. 錯誤碼
| 錯誤碼 | 觸發條件 | 網頁預期行為 |
|---|---|---|
| `invalid_path` | 位置或相對路徑不合法 | 修正參數，不要重試 |
| `not_found` | 檔案、資料夾或授權不存在 | 提示不存在 |
| `already_exists` | `create` 或不覆蓋時目標已存在 | 換名或改 `overwrite` |
| `not_a_directory`、`is_a_directory` | 型別與操作不符 | 修正參數 |
| `not_empty` | 刪非空資料夾但沒有 `recursive` | 確認後帶 `recursive` |
| `too_large` | 內容超過 5 MiB | 改分段 |
| `permission_denied` | 授權失效或被撤銷、系統拒絕 | 重新 `grant` |
| `cross_root_unsupported` | `copy`／`move` 的兩端不在同一根 | 改用讀＋寫 |
| `UNSUPPORTED_PLATFORM` | 該平台沒有這個方法 | 以能力表判斷，不要呼叫 |

### 4. 狀態與規則
- 授權編號由 plugin 產生並持久化，重啟後仍有效；系統撤銷授權後，該編號的操作回 `permission_denied`，`grants` 仍列出它並標示失效前先檢查一次。
- 同一檔案同時寫入：以最後完成者為準，不提供鎖。
- `move` 優先以原子重新命名，跨裝置失敗時退回複製後刪除；失敗不留下一半的目標。

### 5. 相容性
- 本契約是新 plugin，沒有既有消費者；新增方法與回應欄位對舊客戶端安全，刪除或改語意要升修訂號。

### 6. 描述檔的原生宣告
| 功能 | 方法 | Android | iOS | macOS | 備註 |
|---|---|---|---|---|---|
| `sandbox` | 1–8（sandbox 位置） | 無 | 無 | 無 | — |
| `granted` | 1–11（granted 位置） | 無 | 無 | 無 | 平台不支援的方法回 `UNSUPPORTED_PLATFORM` |
| `gallery` | 12 | `WRITE_EXTERNAL_STORAGE`（`maxSdkVersion` 28） | `NSPhotoLibraryAddUsageDescription` | — | — |
| `downloads` | 13 | 無（系統另存視窗） | 無 | 無 | rev 2：原先 Android 9 以前需要寫入權限，改用系統視窗後不需要 |

### 7. 變更紀錄
- **平台註記（2026-11-02）**：Android 的 `grant` 只支援 `directory`（`saf_util` 的單一檔案選擇沒有持久授權，重開機後會失效），`file`、`files` 回 `UNSUPPORTED_PLATFORM`；桌面三種都支援。這是對 §1 #9 的平台限制說明，不改方法與欄位。
- **rev 2（2026-11-02）**：`saveToDownloads` 改為開啟系統的「另存」視窗（`file_picker.saveFile`），不再靜默寫入下載資料夾；`downloads` 不再需要 Android 寫入權限；`from` 的上限 50 MiB（不經 bridge）。原因：Android 靜默寫入需自寫 MediaStore 原生程式、iOS 仍只能用匯出視窗，行為不一致；系統視窗四個平台一致且免權限（使用者選擇）。影響：只有本 repo，尚無消費者。

## Impact Files
全部是新 repo 的新檔案（`(new)`）；骨架由 `aqutter plugin create file-manager` 產生，其餘依下列拆分：
- `aqutter-plugin.json`（new，骨架）— 加入 `native.features`（`gallery`、`downloads`）
- `lib/aqutter_plugin_file_manager.dart`（new，骨架）— 匯出 `FileManagerPlugin`
- `lib/src/file_manager_plugin.dart`（new）— handler 與 `supportedPlatformsFor`
- `lib/src/location.dart`（new）— 位置字串解析、路徑驗證、根解析
- `lib/src/sandbox_store.dart`（new）— sandbox 位置的檔案操作
- `lib/src/grant_store.dart`（new）— 授權清單持久化、授權（granted）的檔案操作
- `lib/src/media_saver.dart`（new）— 相簿與下載
- `android/`、`ios/`（new）— 樹狀授權、bookmark 與媒體儲存的原生程式（視 Q1 決議）
- `src/index.ts`（new，骨架）— `fileManager` 網頁 API 與型別，併入 `AqutterPluginRegistry`
- `test/`（new）— 位置驗證、sandbox 操作、授權清單、錯誤碼、分段讀寫
- `README.md`（new，骨架）— 範圍（含「不做」清單）、原生設定、範例

## App-Flow Screens
（無 app-flow.json，略）

## Open Questions / 待確認事項
### Q1. 原生實作用現成套件還是自己寫 — 影響範圍：`android/`、`ios/`、pubspec
- [x] 現成套件為主：`path_provider`（根）、`gal`（相簿）、`saf_util`＋`saf_stream`（Android 樹狀授權）；iOS 的 bookmark 自己寫 Swift（建議：外部 plugin 不必像內建功能那樣零依賴，套件獨立更新；安全相關的授權只在 iOS 自己寫）
- [ ] 全部自己寫原生程式（與殼的內建功能一致，但工作量大）
- **決議**：已確認　狀態：✅ 已確認

### Q2. 桌面平台範圍 — 影響範圍：`supportedPlatformsFor`、README
- [ ] 第一版只支援 `sandbox` 與 `downloads`，`granted`、`gallery` 回不支援（建議：桌面的授權模型各異，先把行動端做穩）
- [x] 桌面也做 `granted`（以選擇的路徑直接存取，macOS 需處理沙盒 bookmark）
- **決議**：已確認　狀態：✅ 已確認

### Q3. 單次內容上限 — 影響範圍：契約 §2
- [x] 5 MiB（建議：與殼的剪貼簿圖片、分享一致）
- [ ] 10 MiB
- **決議**：已確認　狀態：✅ 已確認

## Manual Follow-ups / 人工收尾事項
- **[合併後]** 用 `aqutter plugin add github:Aqutter/aqutter-plugin-file-manager` 接入範例 App 並在實機驗證 — 需要實機與商店設定 — agent 驗證另開計畫。
- **[上線前]** 用到 `gallery`／`downloads` 的 App 要補 Info.plist 說明文字、確認 Play 資料安全表與 App Store 隱私標籤 — 屬商店申報，agent 不代做。

## Key Decisions
- **[Q1]** 現成套件為主（`path_provider`、`gal`、`saf_util`＋`saf_stream`），iOS bookmark 自己寫。
- **[Q2]** 桌面也做 `granted`（使用者選擇，與計畫建議不同）；`gallery` 仍只有行動端。
- **[Q3]** 單次內容上限 5 MiB。
- **[範圍]** 三層都做（sandbox、granted、gallery／downloads）— 理由：使用者要求更廣泛的檔案管理（使用者選擇）。
- **[名稱]** `aqutter-plugin-file-manager`，id `file-manager` — 使用者指定，涵蓋讀、寫與管理。
- **[建立 repo]** 已在 GitHub Aqutter 組織建立公開 repo（使用者同意）。
- **[不做]** 整機檔案存取與跨根搬移 — 理由：Google Play 受限權限、iOS 無等價物。
- **[流程]** 直接 main、不建 issue（使用者於核准閘確認）。

## Git Completion Policy
- commit 自動；push 與 PR 依核准閘選項。

## References
- `aqutter/docs/plugins.md`（描述檔與 plugin 介面）、`aqutter/shell/lib/src/bridge/bridge_registry.dart`（現有 `PickerPick`）
