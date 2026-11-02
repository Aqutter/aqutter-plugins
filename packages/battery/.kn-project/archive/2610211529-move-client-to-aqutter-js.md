# 2610211529-move-client-to-aqutter-js

- Created: 2026-10-21 15:29 / Archived: 2026-10-21 16:30
- Issue: Aqutter/aqutter-plugin-battery#1
- Milestone: N/A / Base Branch: main

## Summary
`@aqutter/aqutter` 開發依賴改為 `github:Aqutter/aqutter-js#ac7c23b…`，`pnpm-lock.yaml` 重產，`pnpm typecheck` 通過；同時初始化治理結構（`AGENTS.md`、`.kn-project/`，不含 wiki）。

契約 rev 1（正本 `Aqutter/aqutter`，核准日 2026-10-21）：安裝字串為 `github:Aqutter/aqutter-js#<ref>`；manifest `client.spec` 的值改格式、結構不變；舊格式不再支援。PR：https://github.com/Aqutter/aqutter-plugin-battery/pull/2

## Cross-Repo Scope
- **共用計畫 ID**: `2610211529-move-client-to-aqutter-js`　**共用分支名**: `feature/2610211529-move-client-to-aqutter-js`
- **參與 repo 與職責**（一 repo 一 issue，尚未建立者寫 `待建立`）:
  - `Aqutter/aqutter`（契約正本；本計畫）— manifest `client.spec` 改新位置、`manifest-check` 改檢查、文件與治理檔改寫、最後移除 `client/`。issue: 待建立
  - `Aqutter/aqutter-js`（新 repo）— 承接 `client/` 內容與 tag `0.0.0`；建立後另有自己的計畫與 issue。issue: 待建立
  - `Aqutter/aqutter-cli`（消費方）— 辨識新格式、`upgrade` 改寫、`plugin create` 與範本、內建 manifest 快照。issue: 待建立
  - `Aqutter/aqutter-nuxt-app`（下游）— `package.json` 的 client 依賴與 lock。issue: 待建立
  - `Aqutter/aqutter-plugin-battery`、`aqutter-plugin-haptics`、`aqutter-plugin-mirror-demo`、`aqutter-plugin-google-maps`（下游，各自一份計畫）— `package.json` 的 client 依賴與 lock。issue: 待建立
- **執行順序相依**: ① 建立 `aqutter-js` 並匯入內容、打 tag → ② `aqutter`（取得 aqutter-js 的 sha 後改 manifest、文件，並移除 `client/`）合併 → ③ `aqutter-cli`（從合併後的 manifest 同步快照）→ ④ `aqutter-nuxt-app` 與四個 plugin（用新 CLI 的 `upgrade` 或手改依賴，重產 lock）。契約提供方先、消費方後。
- **範圍外**: 不改 npm 套件名；不新增 npm 發佈；bun 驗證；跨 repo CI 比對。

- **本計畫所屬 repo**: `Aqutter/aqutter`

- **本計畫所屬 repo**: `Aqutter/aqutter-plugin-battery`

## Key Decisions
- **[Phase 0]** 整合主幹 `main`；milestone 不指定，base 為 `main`；初始化治理結構（不含 wiki）與一張 issue、一個 PR（使用者選擇）。
- **[契約]** rev 1 凍結（核准日 2026-10-21），正本 `Aqutter/aqutter`。
- **[破壞式移動]** 開發階段不考慮既有程式，不留舊語法相容（使用者指示 2026-10-21）。
- **[ref]** 以 aqutter-js 的 commit sha 固定（與 manifest 相同），不用會移動的 tag。
- **[完成後]** commit + 開 PR（併回 `main`），由使用者合併。

## Deviations
無

## Impact Files
- `package.json:29`（`devDependencies["@aqutter/aqutter"]`）— 改為 `github:Aqutter/aqutter-js#ac7c23b6f8030d97dafa2c798ceb97a90382f6bf`。
- `pnpm-lock.yaml:12-20` — 重新產生（依賴指向 aqutter-js）。
- `AGENTS.md` (new)、`.kn-project/project.md` (new) — 初始化治理結構（使用者選擇）。

## Details
- 驗證與未驗證項目見 PR：https://github.com/Aqutter/aqutter-plugin-battery/pull/2
- 整批工作的合併順序：`Aqutter/aqutter`（#8）→ `Aqutter/aqutter-cli`（#5）→ 範本專案與四個 plugin。
