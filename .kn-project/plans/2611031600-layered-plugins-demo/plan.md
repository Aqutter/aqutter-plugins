# Plan: 2611031600 - layered-plugins-demo
- Created: 2026-11-03
- Branch: N/A（直接 main）
- Issue: N/A（無 issue 追蹤基準）
- Milestone: N/A（未指定）
- Base Branch: main
- Status: In Progress
- Completed: [Wait for Finish]

## Goals
做兩個示範 plugin，與既有的 `location` 組成三層呼叫鏈：網頁 → `place-demo` → `nearby-demo`（internal）→ `location`。驗證 `requires` 的兩層連帶安裝、`internal` 隱藏中間層，以及 `callPlugin` 逐層轉呼叫。

## Architecture
- `nearby-demo`：Dart 端 `internal => true`，`snapshot` 以 `context.callPlugin` 呼叫 `location`。
- `place-demo`：Dart 端 `whereAmI` 以 `context.callPlugin` 呼叫 `nearby-demo.snapshot`；TS 端匯出 `whereAmI()`，併入 `AqutterPluginRegistry`。
- 兩者的 `aqutter-plugin.json` 宣告 `requires`，`package.json` `dependencies` 以 GitHub 子資料夾來源列出被需要的 plugin。
- 用 `aqutter plugin create` 產生後，資料夾改名為不含 `aqutter-plugin-` 前綴（沿用 README 的做法）。

## Cross-Repo Scope
- **本計畫所屬 repo**: `aqutter-plugins`
- **共用計畫 ID**: `2611031600-layered-plugins-demo`　**共用分支名**: N/A（直接 main）
- **參與 repo 與職責**:
  - `aqutter-plugins` — 兩個示範 plugin，契約正本　issue: N/A
  - `aqutter-nuxt-app` — 示範頁、i18n、安裝並在 Android 實機驗證　issue: N/A
- **執行順序相依**: `aqutter-plugins` 先完成並推送，`aqutter-nuxt-app` 才能從 GitHub 安裝。
- **跨 repo 檔案指涉**: `aqutter-nuxt-app` 的 `package.json`、`pnpm-workspace.yaml`、`app/pages/layers.vue`。

## Contract / 介面契約
- **契約正本 repo**: `aqutter-plugins`　**修訂號**: `rev 1`　**狀態**: `草擬`

### 1. Plugin 與呼叫鏈
網頁 → `place-demo`（公開）→ `nearby-demo`（`internal`）→ `location`（既有官方 plugin）。網頁只認識 `place-demo`。

| plugin id | npm 套件 | 需要 | 公開給網頁 |
|---|---|---|---|
| `nearby-demo` | `aqutter-plugin-nearby-demo` | `aqutter-plugin-location` `^0.0.0` | 否（`internal`） |
| `place-demo` | `aqutter-plugin-place-demo` | `aqutter-plugin-nearby-demo` `^0.0.0` | 是 |

### 2. 方法
**`nearby-demo.snapshot`**（只供 `place-demo` 經 `callPlugin` 呼叫）
| 項目 | 內容 |
|---|---|
| 請求 | `{}` |
| 回應 | `{ serviceEnabled: bool, permission: string, position: { latitude: number, longitude: number, accuracy: number } \| null }` |
| 行為 | 先呼叫 `location.capabilities`；`serviceEnabled` 為 `true` 且 `permission` 為 `granted` 才呼叫 `location.getCurrentPosition`（`timeoutMs` 5000），失敗（逾時、無定位）時 `position` 為 `null`，不拋錯 |

**`place-demo.whereAmI`**（網頁呼叫）
| 項目 | 內容 |
|---|---|
| 請求 | `{}` |
| 回應 | `{ layers: ["place-demo", "nearby-demo", "location"], ready: bool, permission: string, position: { latitude, longitude, accuracy } \| null }` |
| 行為 | 呼叫 `nearby-demo.snapshot`；`ready` 為 `serviceEnabled` 且 `permission` 為 `granted`；`layers` 固定列出呼叫鏈，供示範頁顯示 |

### 3. 錯誤碼
| 錯誤碼 | 觸發 | 預期 |
|---|---|---|
| `PLUGIN_NOT_FOUND` | 中間層未登記 | `plugin add` 連帶登記，缺時示範頁顯示錯誤 |
| `HANDLER_NOT_FOUND` | 網頁直接呼叫 `nearby-demo`（internal） | `callPlugin` 回 `undefined`，`isPluginSupported` 為 `false` |

### 4. 狀態與規則
- 無狀態，不快取位置。
- `nearby-demo` 覆寫 `internal` 為 `true`。

### 5. 相容性
- 新增 plugin，不改既有 plugin 與殼。

### 6. 變更紀錄
- _(尚無)_

## Impact Files
- `packages/nearby-demo/` (new) — internal 中間層：`aqutter-plugin.json`、`package.json`、`pubspec.yaml`、`src/index.ts`、`lib/src/nearby_demo_plugin.dart`、`test/`
- `packages/place-demo/` (new) — 公開頂層：同上，TS 端 `whereAmI()`
- `packages/mirror-demo/` — 前例（只參照結構，不修改）
- `README.md:7`（plugin 表格）— 新增兩列
- `package.json`、`pnpm-lock.yaml`（workspace）— 隨新 package 更新

## Open Questions / 待確認事項
### Q1. 兩個示範 plugin 放哪裡 — 影響範圍：`aqutter-plugins`
- [x] 放進 `aqutter-plugins/packages/`，與 `mirror-demo` 同層　(建議，理由：`aqutter plugin add` 的 GitHub 子資料夾來源本來就為此設計，且有前例)
- [ ] 只放在 `aqutter-nuxt-app` 內以 `file:` 安裝
- **決議**：放進 `aqutter-plugins/packages/`　狀態：✅ 已確認

### Q2. 移動 `aqutter-cli` 的 `0.0.0` tag（強推）— 影響範圍：`aqutter-nuxt-app` 的 CLI
- [x] 移動　(建議，理由：`aqutter-nuxt-app` 依賴 `aqutter-cli#0.0.0`，目前的 tag 沒有 `requires` 連帶安裝，不移動就測不到)
- [ ] 不移動，改用本機建置的 CLI 測試
- **決議**：移動 `aqutter-cli` 的 `0.0.0` tag　狀態：✅ 已確認

## Manual Follow-ups / 人工收尾事項
- **[合併後]** 強推 `aqutter-cli` 的 `0.0.0` tag（Q2）— `git tag -f 0.0.0 <hash>`、`git push -f origin 0.0.0` — 強推 tag 需要使用者明確同意

## Key Decisions
- **[設計]** 三層鏈中間層為 `internal` — 理由：同時驗證隱藏與逐層呼叫。
- **[設計]** `nearby-demo.snapshot` 取不到位置時回 `null` 不拋錯 — 理由：室內定位可能逾時，示範頁仍要能顯示呼叫鏈。

- **[Q1]** 兩個示範 plugin 放進 `aqutter-plugins/packages/` — 使用者選擇。
- **[Q2]** 強推 `aqutter-cli` 的 `0.0.0` tag 到含 `requires` 的最新 `main` — 使用者選擇；已核准強推。

## Git Completion Policy
- 開發階段直接推送 `main`，不開 PR／issue／milestone。commit 一律自動。

## References
- 對話：2026-11-03 要求寫多層引用的 plugin 並測試
