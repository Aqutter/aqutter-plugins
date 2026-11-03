<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# Plan: 2611031100 - file-picker-into-file-manager
- Created: 2026-11-03
- Branch: N/A（直接推送 `main`）
- Issue: N/A（本專案開發階段不建 issue）
- Milestone: N/A（未指定）
- Base Branch: main
- Status: In Progress
- Completed: [Wait for Finish]

## Goals
讓 `file-manager` plugin 取代內建 `picker_pick`：新增一次性 `pick(kind, {extensions,title})`，選到的檔案以 `picked:<編號>` 位置交給網頁，之後用既有的 `stat`／`read`／`copy` 操作。

## Architecture
- Dart：`GrantManager` 旁新增 `PickedRegistry`（記憶體內編號→實際路徑，只讀）；`FileManagerPlugin` 的位置解析多認 `picked:`，並限制只能做讀取類操作。選擇器沿用 `file_picker`（可注入假的以便測試）。
- TypeScript：`src/index.ts` 契約新增 `pick`，`fileManager.pick()` 回 `PickedFile[]`，不支援平台回 `[]`。
- 與 `grant` 的差別：`pick` 不寫入偏好設定、不出現在 `grants`、App 重啟即失效。

## Cross-Repo Scope
- **本計畫所屬 repo**: `aqutter-plugins`
- **共用計畫 ID**: `2611031100-file-picker-into-file-manager`　**共用分支名**: 無（直接 `main`）
- **參與 repo 與職責**:
  - `aqutter-plugins` — file-manager 新增 `pick`（契約提供方）　issue: N/A
  - `aqutter-js` — 契約型別將內建 `picker_pick` 標記棄用　issue: N/A
  - `aqutter-nuxt-app` — 示範頁改用 `fileManager.pick`、移除內建 picker composable　issue: N/A
- **執行順序相依**: `aqutter-plugins` 先（可實機驗證 `pick`），`aqutter-js` 與 `aqutter-nuxt-app` 之後（nuxt-app 需要 plugin 新 commit）。
- **跨 repo 檔案指涉**: 無
- **不在本計畫**: 殼 `aqutter` 移除 `file_picker` 依賴與 `picker_pick` 處理器——破壞性變更，等棄用版本發佈後另案。

## Contract / 介面契約
- **契約正本 repo**: `aqutter-plugins`　**修訂號**: `rev 1`　**狀態**: `草擬`

### 1. 方法
| # | 位置 | 名稱 | 用途 |
|---|---|---|---|
| 1 | plugin `file-manager` | `pick` | 開系統選擇器，一次性挑選一或多個檔案；不持久保存、不進授權清單 |

### 2. 請求與回應欄位
**#1 請求** `{ kind: 'file' | 'files', extensions?: string[], title?: string }`
| 欄位 | 型別 | 必填 | 預設 | 限制 |
|---|---|---|---|---|
| `kind` | `'file'` \| `'files'` | 是 | 無 | 其他值回 `invalid_argument`；資料夾不走本方法，仍用 `grant('directory')` |
| `extensions` | `string[]` | 否 | 不限 | 不含點、不分大小寫，如 `['pdf','png']`；空陣列視為不限 |
| `title` | `string` | 否 | 系統預設 | 只在平台支援時作為選擇器標題 |

**#1 回應** `{ items: PickedFile[] }`，取消回 `items: []`
| 欄位 | 型別 | 說明 |
|---|---|---|
| `location` | `string` | `picked:<編號>`；網頁看不到實際路徑 |
| `name` | `string` | 檔名（含副檔名） |
| `size` | `number` | 位元組；取不到時省略 |

### 3. 錯誤碼
| 錯誤碼 | 觸發條件 | 網頁預期行為 |
|---|---|---|
| `invalid_argument` | `kind` 不合法、`extensions` 不是字串陣列 | 屬開發錯誤，直接拋出 |
| `permission_denied` | 對 `picked:` 位置做讀以外的操作（write／delete／move／copy 目的端） | 拋出 `AqutterPluginError` |
| `not_found` | `picked:<編號>` 已失效（App 重啟或檔案被移除） | 重新呼叫 `pick` |

### 4. 狀態與規則
- `picked:<編號>` 只在本次 App 執行期間有效，不寫入持久儲存；App 重啟後失效。
- `picked:` 位置只能讀：`stat`、`read`、`copy` 的來源端；其他操作一律 `permission_denied`。
- Android：選到的是 `file_picker` 複製進 App 快取的檔案；桌面：選到的是原路徑。兩者對網頁都只是 `picked:<編號>`。
- 平台不支援時依「不支援平台不拋錯」契約，`callPlugin` 回 `undefined`，網頁端 `fileManager.pick` 回 `[]`。
- 取消選取回 `items: []`，不是錯誤。

### 5. 相容性
- 既有 `grant`／`grants`／`revoke` 與位置字串（`app-*:`、`granted:`）完全不變；本契約只新增方法與 `picked:` 位置。
- 內建 bridge `picker_pick` 本計畫只標記棄用，行為不變；移除另案。

### 6. 變更紀錄
- _(尚無)_

## Impact Files
- `packages/file-manager/lib/src/file_manager_plugin.dart:85`（方法分派的 `grant`／`grants` 旁）、`:139`（`grant` 處理器）、`:185-207`（位置解析 `_Target`）— 新增 `pick` 方法與 `picked:` 位置解析
- `packages/file-manager/lib/src/location.dart:53-70`（位置字串解析，現只認 `granted:` 與沙盒根）— 加入 `picked:` 前綴
- `packages/file-manager/lib/src/grants.dart:82-100`（`GrantPicker`、`FilePickerGrantPicker`）— 參考其 `file_picker` 呼叫方式；新增選檔用的可注入選擇器（可能放新檔）
- `packages/file-manager/lib/src/picked_registry.dart` (new) — 一次性選取的編號登記，只讀
- `packages/file-manager/src/index.ts:39`（`grant` 契約）、`:67`（`fileManager`）— 契約與網頁 API 新增 `pick`、`PickedFile`
- `packages/file-manager/aqutter-plugin.json` — 依 `native.features` 檢查是否需補宣告（Android 由 `file_picker` 提供，預期不變）
- `packages/file-manager/test/file_manager_plugin_test.dart`、`packages/file-manager/test/unsupported.test.ts` — 新增 `pick` 測試
- `packages/file-manager/README.md`、`packages/file-manager/pubspec.yaml` — 文件與版本說明

## Open Questions / 待確認事項
無（已拍板，見 Key Decisions）

## Manual Follow-ups / 人工收尾事項
- 無（這是純程式碼與文件變更）

## Git Completion Policy
- 本 repo 開發階段直接推送 `main`，不開 PR、milestone、版本分支（見 `.kn-project/project.md`）。commit 一律自動（Rule 17）；完成後依核准閘選項 push。
- 跨 repo：各 repo 自己 commit／push，不存在跨 repo 單一變更；合併次序見 `## Cross-Repo Scope`。
- 程式碼遵守 `kn-project-code-style`（TypeScript／Vue 規則；Dart 沿用該 repo 既有風格）。

## Key Decisions
- **[Q1]** 新增一次性 `pick`，`grant` 不變 — 理由：`grant` 在 Android 只支援資料夾（`aqutter-plugins/packages/file-manager/lib/src/grants.dart` SafGrantPicker 對非 directory 拋不支援），且會持久保存授權；一次性選檔不該進授權清單。使用者 2026-11-03 選擇此方案。
- **[Q2]** 本輪不動殼 — 理由：移除 `picker_pick` 是對所有現有 App 的破壞性變更，先棄用、下一版再移除。
- **[執行中]** 位置字串只認 `picked:<編號>`、不含子路徑；複製以分段讀寫完成（目的端可能是 SAF）— 理由：不需改契約即可滿足 §4
- **[驗證]** Dart 79 個與網頁端測試通過；Windows 實機經 nuxt-app 驗證選取、讀取、取消；Android 未驗證

## References
- 無
