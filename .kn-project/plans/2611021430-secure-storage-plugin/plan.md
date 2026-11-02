# Plan: 2611021430 - secure-storage-plugin
- Created: 2026-11-02
- Branch: N/A（直接 main）
- Issue: N/A（無 issue 追蹤基準）
- Milestone: N/A（未指定）
- Base Branch: main
- Status: Planning
- Completed: [Wait for Finish]

## Goals
官方外部 plugin `secure-storage`：讓網頁把小量機密（登入 token、金鑰）存進系統的安全儲存（iOS／macOS Keychain、Android Keystore 加密儲存、Windows 憑證加密、Linux libsecret），而不是放 `localStorage` 或明文的 `shared_preferences`。並支援**存取條件**：某個項目可要求使用者先通過生物辨識或裝置密碼，才能讀出。

- 與殼的 `shared_preferences` **刻意分開**：後者是明文、會被系統備份；這裡的資料不備份、語意也不同（不能列舉成明文設定、可能因裝置鎖定而讀不到）。
- 網頁端的 `localStorage`／殼的偏好設定不在這個 plugin 範圍；要統一介面可在網頁層包一層（例如 `storage.get(key, { secure: true })`），不屬於本 plugin。

## Architecture
- 全新 repo `aqutter-plugin-secure-storage`，由 `aqutter plugin create secure-storage` 產生骨架；Dart 端 `SecureStoragePlugin`（id `secure-storage`），網頁端 `secureStorage`。
- 原生以現成套件 `flutter_secure_storage`（v11，已含 Android 的 `enforceBiometrics` 與 Apple 的存取控制旗標）為主；不自己寫加密。
- **值是字串**：二進位由呼叫端自行 base64；單一值上限 64 KiB，鍵名 `^[A-Za-z0-9._-]{1,128}$`。
- **命名空間**：plugin 在底層鍵前加固定前綴 `aqutter.ss.`，`keys()` 與 `clear()` 只動這個前綴，不碰同 App 其他程式存在同一個 Keychain 的東西。
- **存取條件**：`set` 可帶 `requireAuth: true`。該項目之後 `get` 會先出現系統的驗證視窗（生物辨識或裝置密碼），通過才回傳值。
  - Android：以 Keystore 金鑰綁定使用者驗證（`enforceBiometrics`）。
  - iOS／macOS：Keychain 存取控制旗標（`userPresence`）。
  - 條件記在該項目本身（寫入時決定），之後不能只改條件不改值；要改就重新 `set`。
  - 裝置沒有設定任何驗證方式：`set(requireAuth: true)` 回 `auth_unavailable`，不降級成不驗證。
- **iOS 存取時機**：預設「第一次解鎖後」（`afterFirstUnlock`，使用者選擇），背景任務也讀得到。
- **備份**：Android 要把這個儲存從自動備份排除（Keystore 金鑰不會被還原，還原後資料無法解開），並在 README 與 `native.note` 說明。
- 平台（第一版）：Android、iOS、macOS、Windows 全功能；Linux 需要 libsecret，回報在能力表之外（`UNSUPPORTED_PLATFORM`）；`requireAuth` 只有 Android、iOS、macOS，桌面的 Windows 回 `auth_unavailable`。

## Cross-Repo Scope
- **本計畫所屬 repo**: `aqutter-plugin-secure-storage`
- **共用計畫 ID**: 無（獨立 repo；使用方是各 App）
- **依賴**: `aqutter` 殼與 plugin 介面（已發佈）、`aqutter-cli` 的描述檔 `native` 宣告與 `--features`（已發佈）。
- **執行順序相依**: 無；範例 App 接入與實機驗證在同一個計畫內完成（Android 實機）。
- **跨 repo 檔案指涉**: `aqutter` 的 `docs/plugins.md`「宣告原生設定」是描述檔 `native` 的契約。

## Contract / 介面契約
- **契約正本 repo**: `aqutter-plugin-secure-storage`　**修訂號**: `rev 1`　**狀態**: `草擬`

### 1. 方法（`callPlugin('secure-storage', <method>, payload)`）
| # | 方法 | 功能 | 請求 | 回應 |
|---|---|---|---|---|
| 1 | `set` | storage、auth（`requireAuth` 時） | `{ key, value, requireAuth?, prompt? }` | `{}` |
| 2 | `get` | storage、auth | `{ key, prompt? }` | `{ value: string \| null }`；項目不存在回 `null`（不是錯誤） |
| 3 | `has` | storage | `{ key }` | `{ exists: boolean }`；**不會**觸發驗證視窗 |
| 4 | `delete` | storage | `{ key }` | `{}`；項目不存在也算成功；刪除**不需要**驗證 |
| 5 | `keys` | storage | `{}` | `{ keys: string[] }`；只列這個 plugin 寫的鍵，不含值 |
| 6 | `clear` | storage | `{}` | `{}`；只清這個 plugin 的鍵 |
| 7 | `capabilities` | — | `{}` | `{ auth: boolean, biometrics: boolean }`：此裝置能否用 `requireAuth`、有沒有生物辨識 |

### 2. 欄位與限制
| 項目 | 規則 |
|---|---|
| `key` | `^[A-Za-z0-9._-]{1,128}$`，其餘 `invalid_key` |
| `value` | 字串，UTF-8 位元組 ≤ 64 KiB，超過 `too_large` |
| `requireAuth` | 布林，預設 `false`；`true` 時需要裝置支援（見 `capabilities`） |
| `prompt` | 驗證視窗的說明文字，≤ 100 字，選填；省略用系統預設 |
| 重複 `set` | 同鍵直接取代（含條件） |

### 3. 錯誤碼
| 錯誤碼 | 觸發條件 | 網頁預期行為 |
|---|---|---|
| `invalid_key` | 鍵名不合法 | 修正參數，不要重試 |
| `too_large` | 值超過 64 KiB | 縮小內容 |
| `auth_unavailable` | `requireAuth` 但裝置沒有設定驗證、或平台不支援 | 以 `capabilities` 判斷後改用一般項目或提示使用者設定 |
| `auth_cancelled` | 使用者取消驗證視窗 | 不算失敗，保留項目；可再試 |
| `auth_failed` | 驗證失敗次數過多或被系統鎖定 | 稍後再試 |
| `key_invalidated` | 系統金鑰已失效（例如使用者新增指紋、重設鎖定畫面） | 項目已無法讀出，視為不存在並重新取得值 |
| `storage_error` | 底層儲存失敗（Keychain 鎖定、Keystore 損壞） | 可重試一次，之後回報 |
| `UNSUPPORTED_PLATFORM` | 平台沒有這個方法 | 以能力表判斷 |

### 4. 狀態與規則
- 帶 `requireAuth` 的項目 `get` 時一定出現驗證視窗；`has`、`keys`、`delete` 不出現。
- `key_invalidated` 後該項目被視為損毀：下一次 `get` 回 `null`，`keys()` 不再列出它。
- 只有成功的 `get` 才會把值交給網頁；取消或失敗不會洩漏任何值。
- 值不會寫進日誌或錯誤訊息。

### 5. 相容性
- 新 plugin，沒有既有消費者；新增方法與回應欄位對舊客戶端安全，刪除或改語意要升修訂號。

### 6. 描述檔的原生宣告
| 功能 | 方法 | Android | iOS | macOS | 備註 |
|---|---|---|---|---|---|
| `storage` | 2–7（不含 `requireAuth`） | 無 | 無 | 無 | 備份排除見 `note` |
| `auth` | 1、2 的 `requireAuth` | `android.permission.USE_BIOMETRIC` | `NSFaceIDUsageDescription` | — | `note`：Android 的 `MainActivity` 必須繼承 `FlutterFragmentActivity` |

### 7. 變更紀錄
- _(尚無)_

## Impact Files
全部是新 repo 的新檔案（`(new)`）；骨架由 `aqutter plugin create secure-storage` 產生：
- `aqutter-plugin.json`（new，骨架）— 加入 `native.features`（`storage`、`auth`）
- `lib/src/secure_storage_plugin.dart`（new）— handler 與 `supportedPlatformsFor`
- `lib/src/secure_store.dart`（new）— 對 `flutter_secure_storage` 的薄介面與實作（前綴、鍵驗證、錯誤對應）
- `src/index.ts`（new，骨架）— `secureStorage` 網頁 API 與型別
- `test/`（new）— 鍵與值驗證、前綴隔離、`requireAuth` 流程、各錯誤碼對應
- `README.md`（new，骨架）— 範圍、原生設定、備份排除、範例
- `pubspec.yaml`（骨架）— 加入 `flutter_secure_storage`

## Open Questions / 待確認事項
### Q1. API 範圍 — 影響範圍：契約 §1
- [x] 簡單鍵值＋存取條件（使用者選擇「加上存取條件」）
- **決議**：簡單鍵值＋`requireAuth`　狀態：✅ 已確認

### Q2. iOS 存取時機 — 影響範圍：Keychain 設定
- [x] 第一次解鎖後 `afterFirstUnlock`（建議）
- **決議**：`afterFirstUnlock`　狀態：✅ 已確認

### Q3. 單一值上限 — 影響範圍：契約 §2
- [ ] 64 KiB（建議：token 與金鑰足夠；Keychain 不適合存大物件）
- [ ] 16 KiB
- **決議**：_(待確認)_　狀態：⏳ 待確認

### Q4. 是否把 Linux 納入 — 影響範圍：`supportedPlatformsFor`、README
- [ ] 第一版不支援 Linux（建議：需要使用者裝 libsecret，行為與其他平台差距大，且我無法在這台機器驗證）
- [ ] 納入，並在 README 寫明 libsecret 需求
- **決議**：_(待確認)_　狀態：⏳ 待確認

## Manual Follow-ups / 人工收尾事項
- **[上線前]** 用到 `auth` 功能的 App 要補 `NSFaceIDUsageDescription`、Android 的 `USE_BIOMETRIC` 與 `FlutterFragmentActivity`，並設定 Android 自動備份排除 — `aqutter doctor` 會檢查前兩項，備份規則 CLI 檢查不到 — 屬使用者的原生檔，agent 不代改。
- **[合併後]** iOS 與 macOS 的 Keychain 與驗證流程需要在 Apple 裝置上驗證 — 這台機器無法編譯 Swift — 由使用者另行測試。

## Key Decisions
- **[範圍]** 簡單鍵值＋存取條件（使用者選擇）。
- **[iOS 存取時機]** `afterFirstUnlock`（使用者選擇）。
- **[套件]** 以 `flutter_secure_storage` v11 為主，不自己寫加密 — 理由：安全相關程式碼自寫風險高，且該版本已支援生物辨識綁定；套件獨立更新也避免拖慢殼的版本。
- **[分離]** 與 `shared_preferences` 分開，網頁層可自行統一介面（先前討論）。
- **[名稱與建立 repo]** `aqutter-plugin-secure-storage`，已在 GitHub Aqutter 組織建立公開 repo（使用者先前同意）。
- **[流程]** 直接 main、不建 issue（待核准時確認）。

## Git Completion Policy
- commit 自動；push 與 PR 依核准閘選項。

## References
- `aqutter/docs/plugins.md`（plugin 介面與原生宣告）、`aqutter-plugin-file-manager`（同型 plugin 的結構與測試做法）
