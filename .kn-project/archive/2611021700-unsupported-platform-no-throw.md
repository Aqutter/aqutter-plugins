# 2611021700 - unsupported-platform-no-throw

- Created: 2026-11-02 17:00 / Archived: 2026-11-02
- Issue: N/A（使用者決議不建 issue）
- Milestone: N/A / Base Branch: main

## Summary
官方 plugin 的網頁 API 配合新型別：用不了時回安全預設值（列表 `[]`、讀取 `null`、寫入不做事），不拋 `TypeError`；七個 package 的 `@aqutter/aqutter` 依賴統一到新版。

## Cross-Repo Scope
- **共用計畫 ID**: `2611021700-unsupported-platform-no-throw`；各 repo 直接 `main`。
- 參與 repo：`aqutter-js`（契約正本）、`aqutter`（殼）、`aqutter-plugins`（官方 plugin 的網頁 API）、`aqutter-nuxt-app`（範例 App 與驗證）。

## 契約（只留引用）
正本是 `aqutter-js` 的 `src/index.ts`（`callPluginRaw`／`callPlugin`）與 `src/contract/models/platform.ts`（`PlatformInfo.dev`），修訂號 rev 1（2026-11-02 凍結，無變更）。要點：平台不支援（`UNSUPPORTED_PLATFORM`）、App 沒裝該 plugin（`HANDLER_NOT_FOUND`）、不在 Flutter 內，三種情況 `callPlugin` 回 `undefined` 不拋錯；其餘錯誤照舊拋出；`platform_info.dev` 為 true 時才在 console 警告一次，正式版安靜；回傳型別 `Res | undefined`。

## Key Decisions
- **[行為]** 不支援的平台回 `undefined`、型別改 `Res | undefined`（使用者選擇）。
- **[沒裝 plugin]** 也回 `undefined` — 網頁包 OTA 更新與殼版本可能落差，編譯期抓不到；開發階段警告補償。
- **[純瀏覽器]** 也回 `undefined`。
- **[警告]** 只在開發階段（`dev`），`console.warn` 一次性；正式版完全安靜。
- **[傳輸不變]** 殼仍回 `UNSUPPORTED_PLATFORM`，轉換只在網頁端，新舊殼與新舊網頁端任意組合都能運作。
- **[流程]** 直接 main、不建 issue。

## Deviations
- **sqlite-drift 是例外**：資料庫用不了時明確拋錯，不回空結果（否則寫入會被默默丟掉）。已寫進 README 與測試。
- battery 的 `level()` 回傳型別變成 `number | null`（API 簽章變動）。

## Impact Files
- `packages/{battery,file-manager,secure-storage,google-maps,sqlite-drift}/src` — 處理 `undefined`
- `packages/*/package.json` — client 依賴統一
- `packages/{battery,file-manager,secure-storage}/test/unsupported.test.ts`（new）、`packages/sqlite-drift/test/dialect.test.ts`
- `README.md` 與各 package 的 README

## Wiki Changes

無（本 repo 沒有 wiki）。
