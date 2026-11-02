# 2611021930 - location-plugin

- Created: 2026-11-02 19:30 / Archived: 2026-11-02
- Issue: N/A（使用者決議不建 issue）
- Milestone: N/A / Base Branch: main

## Summary
官方 plugin `location`：取得裝置位置——取得目前位置一次，或持續監聽位置變化，預設高精度，位於 `packages/location`。只做前景定位，權限沿用殼的權限服務由網頁先要；Android、iOS、macOS、Windows 支援，Linux 不支援。並在範例 App 加一個以 OpenStreetMap（Leaflet）顯示位置的示範頁。

## Cross-Repo Scope
- 本 repo（`aqutter-plugins`）為主；`aqutter` 的 `docs/plugins.md` 官方 plugin 清單加一列；`aqutter-nuxt-app` 接入 OpenStreetMap 示範頁與定位的原生設定。

## 契約（只留引用）
正本是 `packages/location/src/index.ts` 與 `lib/src/location_plugin.dart`，修訂號 rev 1（2026-11-02 凍結，無變更）。方法 `capabilities`、`requestPermission`、`getCurrentPosition`、`startWatching`、`stopWatching`、`openSettings`；事件 `position`、`error`；精度 `high`（預設）、`balanced`、`low`；逾時預設 15 秒（1 到 60 秒）；同時最多 8 個監聽。

## Key Decisions
- **[範圍]** 取得一次＋持續監聽；預設高精度（使用者選擇）；不做背景定位、地理圍欄、地址反查。
- **[逾時]** 預設 15 秒（使用者不確定，採建議值）。
- **[權限]** 沿用殼的權限服務，由網頁先要，不自動跳授權視窗（使用者同意其餘照建議）。
- **[示範]** 範例 App 以 OpenStreetMap（Leaflet）顯示位置（使用者要求）。
- **[流程]** 直接 main、不建 issue。

## Deviations
- 無契約變更。
- 驗證範圍：Android 實機與 Windows 驗證了取得一次、持續監聽與權限／服務狀態查詢；iOS、macOS 未驗證（無法編譯 Swift）；權限被拒或定位服務關閉時的實機行為、Android 背景進出的行為未驗證，只有單元測試涵蓋錯誤對應。
- 範例 App 安裝後 Android 的定位權限被重設為「永久拒絕」，測試時以 adb 重新授權（與通知權限的現象相同，非程式問題）。
- 示範頁使用 OpenStreetMap 公開圖磚伺服器，僅適合示範；正式 App 需改用自己的圖磚來源。

## Impact Files
- `packages/location/**`（new）— plugin 本體、測試、README
- `README.md`（根目錄）— 清單加一列
- `aqutter/docs/plugins.md`（跨 repo）— 清單加一列
- `aqutter-nuxt-app/app/pages/location.vue`、`index.vue`、`package.json`、原生設定（跨 repo）

## Wiki Changes

無（本 repo 沒有 wiki）。
