# 2611031600 - layered-plugins-demo

- Created: 2026-11-03 16:00 / Archived: 2026-11-03
- Issue: N/A（本專案開發階段不建 issue）
- Milestone: N/A / Base Branch: main

## Summary
新增兩個示範 plugin 組成三層呼叫鏈：`place-demo`（公開）`requires` `nearby-demo`（`internal`），後者 `requires` 既有的 `location`；Dart 端逐層以 `context.callPlugin` 轉呼叫，網頁只認識 `place-demo`。用來驗證 `requires` 的兩層連帶安裝、`internal` 隱藏中間層與 `callPlugin`。

## Cross-Repo Scope
- 共用計畫 ID `2611031600-layered-plugins-demo`；各 repo 直接 `main`。
- `aqutter-plugins`（兩個示範 plugin，契約正本）先做，`aqutter-nuxt-app`（示範頁、安裝、實機驗證）後做。
- 契約：網頁 → `place-demo` → `nearby-demo`（`internal`）→ `location`；`nearby-demo.snapshot` 回 `{ serviceEnabled, permission, position | null }`，`place-demo.whereAmI` 回 `{ layers, ready, permission, position | null }`。

## Key Decisions
- **[設計]** 三層鏈的中間層為 `internal` — 同時驗證隱藏與逐層呼叫。
- **[設計]** `nearby-demo.snapshot` 取不到位置時回 `null` 不拋錯 — 室內定位可能逾時。
- **[Q1]** 兩個示範 plugin 放進 `aqutter-plugins/packages/` — 使用者選擇；這樣才能測 GitHub 子資料夾來源的真實連帶安裝。
- **[Q2]** 強推 `aqutter-cli` 的 `0.0.0` tag 到含 `requires` 的最新 `main`（`33a0fba`）— 使用者選擇；`aqutter-nuxt-app` 依賴 `aqutter-cli#0.0.0`。
- **[執行中]** `aqutter-plugins` 與 `aqutter-nuxt-app` 的 `pnpm-workspace.yaml` 設 `blockExoticSubdeps: false` — pnpm 11 預設擋 plugin 的 GitHub 間接依賴；plugin 發佈到 npm 後可移除。
- **[設計]** `nearby-demo` 的 TS 端不併入 `AqutterPluginRegistry` — 避免 internal plugin 的型別洩漏給網頁。
- **[設計]** 示範頁不走 i18n — 同 `plugins.vue`。

## Deviations
- 無契約偏離。
- 驗證：兩個 package 的 `flutter analyze` 無問題；Dart 測試通過（`nearby-demo` 6 個、`place-demo` 4 個，含用真的 `nearby-demo` 走完三層與缺中間層的 `PLUGIN_NOT_FOUND`）；monorepo 的 `pnpm install`、`typecheck` 與既有測試通過；乾淨 pnpm 專案只裝 `place-demo`，連帶安裝 `nearby-demo` 與 `location`，`plugin remove` 對中間層與底層皆被拒絕。
- 首次推送前 monorepo 的 `pnpm install` 會失敗（GitHub 上還沒有 `nearby-demo`），推送後才能安裝；已設 `blockExoticSubdeps: false` 後通過。
- 未驗證：iOS、macOS、Windows；plugin 尚未發佈到 npm，沒有測 npm 來源的相依。

## Impact Files
- `packages/nearby-demo/`、`packages/place-demo/` (new) — 兩個示範 plugin（描述檔、Dart、TS、測試、README）
- `README.md` — plugin 表格新增兩列
- `pnpm-workspace.yaml`、`pnpm-lock.yaml` — `blockExoticSubdeps: false` 與新 package
