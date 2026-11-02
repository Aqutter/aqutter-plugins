# Plan: 2611021830 - biometrics-plugin
- Created: 2026-11-02
- Branch: N/A（直接 main）
- Issue: N/A（無 issue 追蹤基準）
- Milestone: N/A（未指定）
- Base Branch: main
- Status: In Progress
- Completed: [Wait for Finish]

## Goals
官方 plugin `biometrics`：讓網頁在進入敏感操作前（例如打開帳戶頁、確認轉帳）要求使用者**驗證身分一次**，用系統的生物辨識（指紋、臉部）或裝置密碼，並能查詢這個裝置有哪些驗證方式。

- **只做「驗證一次」**（使用者選擇）：不管理金鑰、不儲存任何東西。要「用生物辨識解鎖機密」請用 `secure-storage` 的 `requireAuth`，兩者不重疊。
- **重要限制**：驗證結果只是「這個裝置上、此刻使用者通過了驗證」的客戶端判斷，**不能當作伺服器端的憑證**（網頁端的結果可以被改寫）。要保護機密請用 `secure-storage`；要證明身分給伺服器請走伺服器的登入流程。這點寫進 README。

## Architecture
- 在 `aqutter-plugins` 新增 `packages/biometrics/`，由 `aqutter plugin create biometrics` 產生骨架。Dart 端 `BiometricsPlugin`（id `biometrics`），網頁端 `biometrics`。
- 原生以現成套件 `local_auth`（v3，已是 secure-storage 的依賴）為主，不自己寫。
- **結果一律用狀態回傳，不丟例外**：使用者取消、驗證失敗、被鎖定、裝置不可用都是正常結果，網頁依 `status` 處理；只有參數錯誤才回錯誤碼（`invalid_argument`）。
- **一次只能有一個驗證視窗**：驗證進行中再呼叫，回 `{ status: 'busy' }`，不疊視窗。
- **預設允許裝置密碼備援**（`biometricOnly: false`）：使用者沒有登錄生物辨識、或辨識失敗時可改輸入裝置密碼；`biometricOnly: true` 則只接受生物辨識。
- 平台（第一版）：Android、iOS、macOS、Windows（Windows Hello）；Linux 不支援。
- 不做：金鑰與機密管理、無視窗的「靜默」驗證、紀錄使用者的生物特徵（系統不提供，也不該取得）。

## Cross-Repo Scope
- **本計畫所屬 repo**: `aqutter-plugins`
- **共用計畫 ID**: 無（官方 plugin 在同一個 repo 內）
- **依賴**: `aqutter` 殼與 plugin 介面、`aqutter-cli` 的 `native` 宣告與 `--features`、`aqutter-js` 的 `callPlugin`（回 `undefined` 的新行為）。
- **執行順序相依**: 無；範例 App 接入與 Android 實機驗證在同一個計畫內完成。

## Contract / 介面契約
- **契約正本 repo**: `aqutter-plugins`　**修訂號**: `rev 1`　**狀態**: `凍結（核准日 2026-11-02）`

### 1. 方法（`callPlugin('biometrics', <method>, payload)`）
| # | 方法 | 請求 | 回應 |
|---|---|---|---|
| 1 | `capabilities` | `{}` | `{ available: boolean, biometrics: boolean, types: BiometricType[] }` |
| 2 | `authenticate` | `{ reason, title?, cancelLabel?, biometricOnly? }` | `{ status: AuthStatus }` |

`BiometricType`：`fingerprint`、`face`、`iris`、`strong`、`weak`（依平台能回報的為準，可能為空）。

### 2. 欄位與限制
| 項目 | 規則 |
|---|---|
| `available` | 裝置有可用的驗證方式（生物辨識或裝置密碼／螢幕鎖定） |
| `biometrics` | 裝置已登錄生物辨識（不含只有裝置密碼的情況） |
| `reason` | 驗證視窗顯示的說明文字，必填，1 到 100 字 |
| `title` | 選填，≤ 60 字：視窗標題；只有 Android 使用，其他平台忽略 |
| `cancelLabel` | 選填，≤ 30 字：取消按鈕文字；Android 與 iOS 使用，其他平台忽略 |
| `biometricOnly` | 布林，預設 `false`；`true` 時只接受生物辨識，沒有登錄生物辨識回 `unavailable` |

### 3. `AuthStatus`
| 狀態 | 意義 | 網頁預期行為 |
|---|---|---|
| `authenticated` | 使用者通過驗證 | 繼續敏感操作 |
| `cancelled` | 使用者取消，或系統中斷了視窗 | 不繼續，不算錯誤 |
| `failed` | 驗證沒有通過（辨識不符） | 可重試 |
| `locked_out` | 嘗試太多次，暫時鎖定 | 稍後再試，或改用裝置密碼 |
| `permanently_locked_out` | 生物辨識被鎖住，需要使用者以裝置密碼解鎖 | 提示使用者到系統解鎖 |
| `unavailable` | 裝置沒有可用的驗證方式（沒有硬體、沒有登錄、沒有螢幕鎖定），或 `biometricOnly` 但沒有生物辨識 | 以 `capabilities` 判斷後改用其他流程 |
| `busy` | 已經有一個驗證視窗在進行中 | 等待上一個結果 |

### 4. 錯誤碼
| 錯誤碼 | 觸發條件 |
|---|---|
| `invalid_argument` | `reason` 缺漏、不是字串或長度不合法；`title`、`cancelLabel` 不是字串或超過長度；`biometricOnly` 不是布林 |

### 5. 狀態與規則
- 驗證結果**不留存**：每次呼叫都重新驗證，plugin 不快取「剛剛驗證過」。
- 不會把任何生物特徵、裝置密碼或底層的原始錯誤訊息交給網頁。
- 平台不支援時（Linux），網頁端 `callPlugin` 回 `undefined`，網頁 API 回 `{ status: 'unavailable' }`。

### 6. 相容性
- 新 plugin，沒有既有消費者；新增狀態值或欄位對舊客戶端要容許未知狀態，刪除或改語意要升修訂號。

### 7. 描述檔的原生宣告
| 功能 | 方法 | Android | iOS | macOS | 備註 |
|---|---|---|---|---|---|
| `authenticate` | 1、2 | `android.permission.USE_BIOMETRIC` | `NSFaceIDUsageDescription` | `NSFaceIDUsageDescription` | `note`：Android 的 `MainActivity` 必須繼承 `FlutterFragmentActivity` |

### 8. 變更紀錄
- _(尚無)_

## Impact Files
全部是新檔案（`(new)`）；骨架由 `aqutter plugin create biometrics` 產生：
- `packages/biometrics/aqutter-plugin.json`（new，骨架）— 加入 `native.features`
- `packages/biometrics/lib/src/biometrics_plugin.dart`（new）— handler 與平台宣告
- `packages/biometrics/lib/src/authenticator.dart`（new）— 對 `local_auth` 的薄介面、結果對應
- `packages/biometrics/src/index.ts`（new，骨架）— 網頁端 API 與型別，不支援時回安全預設值
- `packages/biometrics/test/`（new）— 狀態對應、參數驗證、`busy`、`biometricOnly`
- `packages/biometrics/README.md`（new，骨架）— 範圍、限制（客戶端判斷不是伺服器憑證）、原生設定
- `packages/biometrics/package.json`、`pubspec.yaml`（骨架）— 加入 `local_auth`
- `README.md`（既有，根目錄）— 官方 plugin 清單加一列
- `aqutter/docs/plugins.md`（既有，跨 repo）— 官方 plugin 清單加一列

## Open Questions / 待確認事項
### Q1. Windows 是否納入第一版 — 影響範圍：`supportedPlatforms`
- [x] 納入（建議：`local_auth` 支援 Windows Hello，這台開發機可以實測）
- [ ] 不納入，只做 Android、iOS、macOS
- **決議**：照建議　狀態：✅ 已確認

### Q2. 預設是否允許裝置密碼備援 — 影響範圍：`biometricOnly` 預設值
- [x] 預設允許（`biometricOnly: false`）（建議：沒登錄生物辨識的使用者仍可用裝置密碼，較不會把人擋在外面）
- [ ] 預設只接受生物辨識
- **決議**：照建議　狀態：✅ 已確認

## Manual Follow-ups / 人工收尾事項
- **[上線前]** 用到的 App 補 `USE_BIOMETRIC`、`NSFaceIDUsageDescription`、`FlutterFragmentActivity` — `aqutter doctor` 會檢查前兩項 — 屬使用者的原生檔，agent 不代改。
- **[合併後]** 驗證成功路徑需要有螢幕鎖定或生物辨識的裝置，iOS 與 macOS 需要 Apple 裝置 — 這台機器的手機沒有螢幕鎖定，且無法編譯 Swift — 由使用者另行測試。

## Key Decisions
- **[通用性]** plugin 完全不知道它在保護什麼，任何時候都能叫起（沒有前置條件、不快取）；新增選填的 `title`、`cancelLabel` 讓網頁控制視窗文字（使用者要求）。
- **[Q1]** Windows 納入；**[Q2]** 預設允許裝置密碼備援。
- **[範圍]** 只做「驗證一次」，不管理金鑰（使用者選擇）；與 `secure-storage` 的 `requireAuth` 分工。
- **[結果]** 一律用狀態回傳、不丟例外（取消與失敗是正常結果）。
- **[限制]** 驗證結果是客戶端判斷，不是伺服器憑證，寫進 README。
- **[流程]** 直接 main、不建 issue（使用者於核准閘確認）。

## Git Completion Policy
- commit 自動；push 與 PR 依核准閘選項。

## References
- `packages/secure-storage`（同型 plugin 的結構、錯誤對應與測試做法）、`aqutter/docs/plugins.md`（描述檔與原生宣告）
