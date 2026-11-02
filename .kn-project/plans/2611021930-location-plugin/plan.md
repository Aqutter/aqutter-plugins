# Plan: 2611021930 - location-plugin
- Created: 2026-11-02
- Branch: N/A（直接 main）
- Issue: N/A（無 issue 追蹤基準）
- Milestone: N/A（未指定）
- Base Branch: main
- Status: Planning
- Completed: [Wait for Finish]

## Goals
官方 plugin `location`：讓網頁取得裝置位置——**取得目前位置一次**，也能**持續監聽**位置變化。預設高精度（使用者要求）。並在範例 App 加一個用 **OpenStreetMap** 顯示位置的示範頁，展示定位功能。

- **只做前景定位**：App 在使用中才定位；不做背景定位（需要額外的危險權限、Android 的前景服務與商店審核，建議之後有明確需求再開新計畫）。
- **權限沿用殼的權限服務**（`context.requestPermission('locationWhenInUse')`），plugin 不自己相依權限套件；權限由網頁先要，沒有授權時呼叫回 `permission_denied`，不會自動跳授權視窗（與通知的做法一致）。
- 隱私：位置是敏感資料。plugin 不保存、不上傳、不寫日誌；使用這個 plugin 的 App 要自行處理商店的隱私申報（Google Play 資料安全表、App Store 隱私標籤）。

## Architecture
- 在 `aqutter-plugins` 新增 `packages/location/`，由 `aqutter plugin create location` 產生骨架。Dart 端 `LocationPlugin`（id `location`），網頁端 `location`。
- 原生以現成套件 `geolocator`（v14）為主，不自己寫。
- **取得一次** `getCurrentPosition`：有逾時（預設 15 秒，使用者不確定，我選用這個值：冷啟動的 GPS 首次定位常需 5 到 30 秒，15 秒是「不太久、多數情況拿得到」的折衷；可由呼叫端調整，上限 60 秒）。
- **持續監聽** `startWatching`：回傳 `watchId`，位置以事件 `position` 推送、錯誤以事件 `error` 推送；`stopWatching` 停止。同時最多 8 個監聽，超過回 `too_many_watches`。App 結束或殼釋放 plugin 時全部自動停止。
- **精度三檔**：`high`（預設）、`balanced`、`low`，對應系統的最佳／中等／低精度；`distanceFilterMeters` 與 `intervalMs`（選填，僅作為提示，系統可能忽略）。
- 平台（第一版）：Android、iOS、macOS、Windows；Linux 不支援（需要 geoclue、行為差距大，且這台機器無法驗證）。
- 不做：背景定位、地理圍欄、地址反查（geocoding）、模擬位置的偵測以外的任何位置修改。

## Cross-Repo Scope
- **本計畫所屬 repo**: `aqutter-plugins`
- **共用計畫 ID**: 無（官方 plugin 在同一個 repo 內）
- **參與**: `aqutter-plugins`（plugin 本體）、`aqutter`（`docs/plugins.md` 清單加一列）、`aqutter-nuxt-app`（OpenStreetMap 示範頁與 Android／Windows 驗證）。
- **執行順序相依**: plugin push 後，範例 App 才能從 GitHub 安裝。

## Contract / 介面契約
- **契約正本 repo**: `aqutter-plugins`　**修訂號**: `rev 1`　**狀態**: `草擬`

### 1. 方法與事件（`callPlugin('location', <method>, payload)`、`onPluginEvent('location', <event>, …)`）
| # | 名稱 | 請求 | 回應 |
|---|---|---|---|
| 1 | `capabilities` | `{}` | `{ serviceEnabled: boolean, permission: PermissionStatus }` |
| 2 | `requestPermission` | `{}` | `{ permission: PermissionStatus }`（必要時跳系統授權視窗） |
| 3 | `getCurrentPosition` | `{ accuracy?, timeoutMs? }` | `{ position: Position }` |
| 4 | `startWatching` | `{ accuracy?, distanceFilterMeters?, intervalMs? }` | `{ watchId: number }` |
| 5 | `stopWatching` | `{ watchId }` | `{}`；沒有這個編號也算成功 |
| 6 | `openSettings` | `{ target: 'app' \| 'location' }` | `{}`：`app` 開本 App 的系統設定、`location` 開系統的定位服務設定 |
| 事件 | `position` | — | `{ watchId, position: Position }` |
| 事件 | `error` | — | `{ watchId, code }`（錯誤碼同 §3；監聽在錯誤後**不會**自動停止，除非是 `permission_denied` 或 `location_services_disabled`，這兩種會先送 `error` 再自動結束該監聽） |

`Position`：`{ latitude, longitude, accuracy, altitude?, altitudeAccuracy?, heading?, speed?, timestamp, isMocked? }`；經緯度為度、`accuracy` 與 `altitudeAccuracy` 為公尺、`heading` 為度（0 到 360）、`speed` 為公尺／秒、`timestamp` 為 Unix 毫秒；平台沒有的欄位省略。

### 2. 欄位與限制
| 項目 | 規則 |
|---|---|
| `accuracy` | `high`（預設）、`balanced`、`low`，其餘 `invalid_argument` |
| `timeoutMs` | 整數 1,000 到 60,000，預設 15,000，超出範圍 `invalid_argument` |
| `distanceFilterMeters` | 整數 0 到 10,000，預設 0（不過濾） |
| `intervalMs` | 整數 500 到 3,600,000，僅作提示 |
| 同時監聽數 | 最多 8，超過 `too_many_watches` |
| `PermissionStatus` | 沿用殼的權限狀態字串：`granted`、`denied`、`permanentlyDenied`、`restricted`、`limited`、`prompt` |

### 3. 錯誤碼
| 錯誤碼 | 觸發條件 | 網頁預期行為 |
|---|---|---|
| `invalid_argument` | 參數缺漏、型別或範圍不合法 | 修正參數 |
| `permission_denied` | 沒有定位權限 | 先 `requestPermission`；永久拒絕時引導 `openSettings({ target: 'app' })` |
| `location_services_disabled` | 系統的定位服務關閉 | 引導 `openSettings({ target: 'location' })` |
| `timeout` | `getCurrentPosition` 在逾時內沒取得位置 | 可放寬精度或延長逾時後重試 |
| `position_unavailable` | 系統無法取得位置（例如室內無訊號、硬體錯誤） | 稍後重試 |
| `too_many_watches` | 同時監聽超過 8 個 | 先停止不需要的監聽 |
| `UNSUPPORTED_PLATFORM` | 平台沒有這個 plugin（Linux） | 網頁端轉成 `undefined`，網頁 API 回安全預設值 |

### 4. 狀態與規則
- 位置不快取：每次 `getCurrentPosition` 都向系統要新的位置。
- 持續監聽只在 App 在前景時保證運作；App 進背景時系統可能暫停，回到前景後繼續（不保證補送錯過的位置）。
- `startWatching` 在沒有權限時**不**自動要權限，回 `permission_denied`（與 `getCurrentPosition` 一致）。
- 位置不會寫進日誌、錯誤訊息或事件以外的任何地方。

### 5. 相容性
- 新 plugin，沒有既有消費者；新增欄位對舊客戶端安全，刪除或改語意要升修訂號。

### 6. 描述檔的原生宣告
| 功能 | 方法 | Android | iOS | macOS | 備註 |
|---|---|---|---|---|---|
| `locate` | 1–6 | `ACCESS_FINE_LOCATION`、`ACCESS_COARSE_LOCATION` | `NSLocationWhenInUseUsageDescription` | `NSLocationWhenInUseUsageDescription` | `note`：macOS 沙盒 App 還需要 entitlement `com.apple.security.personal-information.location`；Windows 要在系統設定開啟定位服務；使用位置的 App 要自行處理 Play 資料安全表與 App Store 隱私標籤 |

### 7. 變更紀錄
- _(尚無)_

## Impact Files
- `packages/location/**`（new；骨架由 `aqutter plugin create location` 產生）— `aqutter-plugin.json`、`lib/src/location_plugin.dart`、`lib/src/locator.dart`（對 `geolocator` 的薄介面與錯誤對應）、`src/index.ts`、`test/`、`README.md`、`package.json`／`pubspec.yaml`
- `README.md`（既有，根目錄）— 官方 plugin 清單加一列
- `aqutter/docs/plugins.md`（既有，跨 repo）— 官方 plugin 清單加一列
- `aqutter-nuxt-app/app/pages/location.vue`（new，跨 repo）— OpenStreetMap 示範頁
- `aqutter-nuxt-app/app/pages/index.vue`、`package.json`（既有，跨 repo）— 連結與 `leaflet` 依賴
- `aqutter-nuxt-app/aqutter/android/app/src/main/AndroidManifest.xml`、`ios/Runner/Info.plist`、`macos/Runner/Info.plist`、`macos/Runner/*.entitlements`（既有，跨 repo）— 定位的權限與說明文字

## Open Questions / 待確認事項
### Q1. 定位逾時的預設值 — 影響範圍：契約 §2
- [ ] 15 秒（建議：冷啟動的 GPS 首次定位常需 5 到 30 秒，15 秒是多數情況拿得到、又不會等太久的折衷）
- [ ] 30 秒
- [ ] 10 秒
- **決議**：_(待確認)_　狀態：⏳ 待確認

### Q2. OpenStreetMap 示範頁的地圖函式庫 — 影響範圍：範例 App
- [ ] Leaflet（建議：成熟、體積小、直接顯示 OpenStreetMap 的圖磚；以 npm 套件安裝，不依賴 CDN）
- [ ] MapLibre GL（向量圖磚，需要另找圖磚來源，OpenStreetMap 官方圖磚是點陣圖）
- **決議**：_(待確認)_　狀態：⏳ 待確認

## Manual Follow-ups / 人工收尾事項
- **[上線前]** 用到的 App 補 Android 的 `ACCESS_FINE_LOCATION`、`ACCESS_COARSE_LOCATION`、iOS 與 macOS 的 `NSLocationWhenInUseUsageDescription`、macOS 沙盒的定位 entitlement，並處理商店的隱私申報 — `aqutter doctor` 會檢查前三項 — 屬使用者的原生檔與商店設定，agent 不代做。
- **[上線前]** 示範頁使用 OpenStreetMap 的公開圖磚伺服器：[圖磚使用政策](https://operations.osmfoundation.org/policies/tiles/)只允許輕量使用且要標示出處，正式 App 請改用自己的圖磚來源或付費服務 — 屬使用條款，agent 不代處理。
- **[合併後]** iOS 與 macOS 需要 Apple 裝置驗證 — 這台機器無法編譯 Swift — 由使用者另行測試。

## Key Decisions
- **[範圍]** 取得一次＋持續監聽；預設高精度（使用者選擇）；不做背景定位、地理圍欄、地址反查。
- **[權限]** 沿用殼的權限服務，由網頁先要，不自動跳授權視窗（使用者同意「其他根據建議」）。
- **[示範]** 範例 App 加一個以 OpenStreetMap 顯示位置的頁面（使用者要求）。
- **[流程]** 直接 main、不建 issue（待核准時確認）。

## Git Completion Policy
- commit 自動；push 與 PR 依核准閘選項。

## References
- `packages/biometrics`、`packages/secure-storage`（同型 plugin 的結構與測試做法）、`aqutter/docs/plugins.md`（權限與原生宣告）
