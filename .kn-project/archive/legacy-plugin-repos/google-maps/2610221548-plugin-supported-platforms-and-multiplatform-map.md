# 2610221548-plugin-supported-platforms-and-multiplatform-map

- Created: 2026-10-22 15:48 / Archived: 2026-10-22 19:00
- Issue: Aqutter/aqutter-plugin-google-maps#3
- Milestone: N/A / Base Branch: main

## Summary
地圖 plugin 自己提供多平台能力：Android、iOS 用原生地圖（`google_maps_flutter`，鏡像到 `<aqutter-native>`），其他平台（macOS、Windows、Linux、純瀏覽器）用 Google Maps JavaScript API。網頁只寫一份 `googleMaps.mount(container)`，回傳的 `GoogleMapsView` 在兩個 provider 下方法與事件一致，都能在地圖上疊 HTML。Dart 端宣告 `supportedPlatforms => {android, iOS}`（依賴 `Aqutter/aqutter#13`），網頁以同步的 `provider()` 切換；JS API key 由使用端 `googleMaps.configure({ jsApiKey })` 傳入。頂層的 `isSupported`、`moveTo`、`setMarkers` 等已移除（開發階段破壞式變更）。

## Cross-Repo Scope
- `Aqutter/aqutter`（契約正本，PR #13）— `AqutterPlugin.supportedPlatforms`。
- `Aqutter/aqutter-js`（PR #2）— `callPlugin` 轉換 `aqutterError`。
- `Aqutter/aqutter-plugin-google-maps`（本 repo）— 多平台地圖。

## Key Decisions
- **[Q1]** 宣告粒度＝plugin 層級（建議項）。
- **[Q2]** 非原生平台用 Google Maps JavaScript API（使用者選擇，未採納建議的 MapLibre）— 後果：需另一組 JS API key 與計費、必須從 Google 載入腳本（無法離線）。
- **[Q3]** 名稱維持 `aqutter-plugin-google-maps`。
- **[Q4]** key 由網頁端 `googleMaps.configure({ jsApiKey })` 傳入（建議項）— plugin 不讀檔案、不把 key 寫進 repo。
- **[契約 rev 2]** 不支援平台的呼叫由殼回傳 `aqutterError` 資料、`aqutter-js` 轉成拋出。
- **[完成後]** commit + 開 PR。

## Deviations
- 契約由 rev 1 改為 rev 2（Rule 29）。
- 計畫的最後一個任務「在非原生平台實際載入 JS 地圖」**沒有完成**：沒有 Google Maps JavaScript API key（需要使用者的帳號與計費），所以 JS 地圖只用假的 `google.maps` 物件做過單元測試。

## Details
- 驗證：`pnpm exec tsc --noEmit` 通過；TS 單元測試 23 個全過（載入器、JS provider、`provider()` 切換、原生 provider）；`flutter analyze` No issues found、`flutter test` 15 個全過。
- 端對端（Windows，範本專案的暫存複本裝入本 plugin）：`isPluginSupported('google-maps','moveTo')` 為 false、`provider()` 為 `'js'`、直接 `callPlugin` 得到 `AqutterPluginError`（`UNSUPPORTED_PLATFORM`）而不是卡住、沒設 key 時 `mount` reject 並提示呼叫 `configure`。
- **未驗證**：真的 Google Maps JavaScript API 載入（CSP 需放行的確切網域、release 版 `http://127.0.0.1:<隨機埠>` 下 key 的網址限制怎麼填、載入網址沒有加 `loading=async`）；原生路徑（iOS、Android）沒有重跑，只確認 Dart 端與型別。README 已把這幾項標為未驗證。
- 人工收尾：Google Cloud Console 啟用 Maps JavaScript API 並建立 JS API key（需帳號與計費）；使用端 App 傳入 key 並放行 CSP。
