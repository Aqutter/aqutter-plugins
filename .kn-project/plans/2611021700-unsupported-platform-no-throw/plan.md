# Plan: 2611021700 - unsupported-platform-no-throw
- Created: 2026-11-02
- Branch: N/A（直接 main）
- Issue: N/A（無 issue 追蹤基準）
- Milestone: N/A（未指定）
- Base Branch: main
- Status: In Progress
- Completed: [Wait for Finish]

## Goals
各官方 plugin 的網頁 API 配合新型別：`callPlugin` 可能回 `undefined`，不支援時回安全的預設值，不拋 `TypeError`，並補測試與 README 說明。

## Architecture
契約與完整設計見 `aqutter-js` 的同名計畫（契約正本）：不支援的平台呼叫 plugin 回 `undefined`、型別為 `Res | undefined`、只在開發階段警告。本 repo 依該契約實作自己的部分。

## Cross-Repo Scope
- **本計畫所屬 repo**: `aqutter-plugins`
- **共用計畫 ID**: `2611021700-unsupported-platform-no-throw`；各 repo 直接 `main`。
- **參與 repo**: `aqutter-js`（契約正本）、`aqutter`、`aqutter-plugins`、`aqutter-nuxt-app`。
- **執行順序相依**: `aqutter-js` 先 push；其餘依賴新型別，等它之後。

## Contract / 介面契約
見 `aqutter-js` 的同名計畫 `## Contract / 介面契約`（逐字相同的區塊不在此重複，避免兩份漂移；以契約正本為準）。

## Impact Files
- `packages/*/src/index.ts`（共 7 個 plugin、約 36 處 `callPlugin`）— 處理 `undefined`，各方法的預設值寫進 README
- `packages/*/test/` 或網頁端測試（new）— 不支援時的預設值
- `packages/*/README.md` — 「不支援的平台」一節
- 各 package 的 `@aqutter/aqutter` 依賴 — 統一到新的 aqutter-js 版本

## Open Questions / 待確認事項
同 `aqutter-js` 的同名計畫（Q1 沒裝 plugin、Q2 純瀏覽器、Q3 警告出口）；本 repo 不另有待確認事項。

## Manual Follow-ups / 人工收尾事項
無

## Key Decisions
- 見 `aqutter-js` 的同名計畫。

## Git Completion Policy
- commit 自動；push 依核准閘選項。
