# Plan: 2611171140 - map-passthrough-spike
- Created: 2026-11-17
- Branch: feature/2611171140-map-passthrough-spike
- Issue: Aqutter/aqutter-plugins#7
- Milestone: N/A（未指定）
- Base Branch: main
- Status: In Progress
- Completed: [Wait for Finish]

## Goals
驗證「方案 2」：Android 上的原生 Google 地圖不再鏡像到網頁 canvas，改為直接畫在 Flutter 裡、放在透明的 WebView 下面，網頁 HTML 疊在地圖之上、觸控由網頁轉成地圖手勢。本計畫只做驗證，**不併入主幹**，產出一份驗證報告（效能、手感、限制、建議）。

驗收問題：
1. 地圖能否透過透明 WebView 正確顯示，HTML 疊層（按鈕、卡片）能否在地圖之上？
2. 拖曳、雙指縮放、點擊能否正確驅動地圖？
3. 與現行鏡像模式相比，掉幀與延遲如何？
4. 有沒有鏡像模式沒有的問題（觸控穿透、鍵盤、WebView 捲動衝突、合成順序）？

## Architecture
- 現況：`GoogleMapsPlugin.buildUnderlay` 把 `GoogleMap` 包在 `AqutterNative` 裡鏡像給網頁（`packages/google-maps/lib/src/google_maps_plugin.dart:161-213`），Android 為了讓擷取成立還強制 texture 模式（同檔 `:153-157`）。
- 實驗：`AQUTTER_MAP_PASSTHROUGH=true` 時，`buildUnderlay` 直接回傳滿版 `GoogleMap`（不包 `AqutterNative`、不擷取），並新增 `gesture` handler，把網頁送來的語意手勢交給既有的 `AqutterMapGestureMapper`（`lib/src/gesture_mapper.dart`）與 `_applyPending`。
- 網頁端：`packages/google-maps/src/nativeProvider.ts:12` 的 `createNativeView` 在不鏡像模式下不建立 `<aqutter-native>`，改建立透明容器，監聽 pointer 事件並換成 pan／pinch／doubleTap／tap。需要殼回報目前模式，用 `callPlugin('google-maps', 'mode')`。
- 量測：以 `adb shell dumpsys gfxinfo <package> reset` / `framestats` 比較兩種模式在連續拖曳與縮放 10 秒內的 janky frames 與 50/90/95/99 百分位幀時間；手感與穿透問題以實機操作加截圖記錄。

## Cross-Repo Scope
- **本計畫所屬 repo**: `aqutter-plugins`
- **共用計畫 ID**: `2611171140-map-passthrough-spike`　**共用分支名**: `feature/2611171140-map-passthrough-spike`
- **參與 repo 與職責**:
  - `aqutter` — 提供 `AQUTTER_WEBVIEW_TRANSPARENT` 開關　issue: `Aqutter/aqutter#67`
  - `aqutter-plugins` — 不鏡像模式、手勢轉送、量測、驗證報告　issue: `Aqutter/aqutter-plugins#7`
- **執行順序相依**: aqutter 先（開關），本 repo 後；在 `aqutter-nuxt-app` 以本機路徑覆寫串起來。
- **跨 repo 檔案指涉**: `aqutter` 的 `shell/lib/src/app.dart`（只讀其開關，不在本 repo 修改）。

## Contract / 介面契約
- **契約正本 repo**: `aqutter`　**修訂號**: `rev 1`　**狀態**: `凍結（核准日 2026-11-17）`

（與 `aqutter` 那份逐字相同的部分）

| 鍵 | 讀取者 | 值 | 預設 | 作用 |
|---|---|---|---|---|
| `AQUTTER_WEBVIEW_TRANSPARENT` | 殼（`aqutter`） | `true` / `false` | `false` | `true` 時 WebView 背景透明 |
| `AQUTTER_MAP_PASSTHROUGH` | 地圖 plugin（`aqutter-plugins`） | `true` / `false` | `false` | `true` 時地圖不鏡像，直接畫在 WebView 下面 |

- 兩個鍵必須同時為 `true` 才有意義；只開 plugin 的鍵，地圖會被不透明的 WebView 蓋住。
- 相容性：兩者預設 `false`，不影響任何既有 App。
- 變更紀錄：_(尚無)_

本 repo 內部（plugin Dart ↔ 網頁）的實驗訊息，不屬對外契約：handler `mode`（回 `{passthrough: bool}`）、handler `gesture`（payload 沿用 `AqutterMapGestureMapper` 吃的語意手勢，欄位於實作時依 `lib/src/gesture_mapper.dart` 定案並記入 `## Key Decisions`）。

## Impact Files
- `packages/google-maps/lib/src/google_maps_plugin.dart:161` (`buildUnderlay`) — 不鏡像分支：直接回傳滿版 `GoogleMap`。
- `packages/google-maps/lib/src/google_maps_plugin.dart:90` (`handlers`) — 新增 `mode`、`gesture`。
- `packages/google-maps/lib/src/google_maps_plugin.dart:148` (`attach`) — 不鏡像時不強制 texture 模式（`:156`）。
- `packages/google-maps/src/nativeProvider.ts:12` (`createNativeView`) — 不鏡像模式：透明容器＋pointer 手勢轉送。
- `.kn-project/archive/2611171140-map-passthrough-spike.md` (new) — 驗證報告（歸檔時產生）。

## App-Flow Screens
（無 app-flow.json，刪除）

## Open Questions / 待確認事項
### Q1. 地圖區域的觸控怎麼交給地圖？— 影響範圍：`nativeProvider.ts`、`google_maps_plugin.dart`
- [x] 選項 A：網頁監聽 pointer 事件，換成語意手勢後經 `callPlugin` 送給 plugin，沿用 `AqutterMapGestureMapper`　(建議，理由：不動 aqutter_core 與 aqutter-js，驗證成本最低)
- [ ] 選項 B：沿用 `<aqutter-native>` 但關掉影格串流　(需改 aqutter_core 與 aqutter-js)
- **決議**：選項 A　狀態：✅ 已確認

## Manual Follow-ups / 人工收尾事項
無 — 純實驗，沒有 migration、對外 env 鍵、部署或第三方主控台設定。Google Maps 的 Android key 已在 nuxt-app 設好（見 `aqutter-nuxt-app` 的環境設定），驗證直接使用。

## Key Decisions
- **[Phase 0]** 目標 repo：`aqutter`、`aqutter-plugins`；使用者確認走「實驗分支，不併入主幹」。
- **[Milestone]** 不指定，以 `main` 為 base — 使用者於 Phase 0 選擇。
- **[Q1]** 觸控由網頁監聽 pointer 轉語意手勢，經 `callPlugin` 送 plugin — 理由：不動 aqutter_core 與 aqutter-js，驗證成本最低。
- **[範圍]** 只驗證 Android（ASUS I006D、Android 13、API 33）；iOS 沒有設備，標記未驗證。桌面平台本來就用 JS 地圖，不在範圍。
- **[程式碼風格]** 實作遵守 `kn-project-code-style`（TypeScript、Dart 規則）。
- **[契約]** rev 1 凍結（核准日 2026-11-17）。
- **[執行模式]** 序列（依據：plugin 的實測依賴殼的開關，且只有一支實機；先 aqutter 後 aqutter-plugins）。
- **[完成後]** commit + push（實驗分支，不歸檔、不開 PR）；驗證完成後再與使用者決定去留。

## Git Completion Policy
- PR 一律以 `--base main` 顯式指定 base（若最後要開 PR）。
- Issue 綁定時，每個 commit 訊息都含 `Closes #${N}`。
- 實驗分支預計**不併入主幹**；完成後的動作見核准閘。

## References
- 前一輪討論：鏡像 google map 的替代方案（方案 2 = 透明洞穿透）。
- 既有鏡像基準：`aqutter/tools/channel-bench/README.md`。
