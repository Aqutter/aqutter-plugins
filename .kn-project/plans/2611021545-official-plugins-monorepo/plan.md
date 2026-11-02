# Plan: 2611021545 - official-plugins-monorepo
- Created: 2026-11-02
- Branch: N/A（直接 main）
- Issue: N/A（無 issue 追蹤基準）
- Milestone: N/A（未指定）
- Base Branch: main
- Status: Planning
- Completed: [Wait for Finish]

## Goals
把官方 plugin 從「一個 plugin 一個 repo」合併成單一 repo `aqutter-plugins`（pnpm workspace，`packages/<id>/`）。動機（使用者決定）：殼或契約變動時一個 PR 改全部、工具與測試共用一份、一個 tag 對應一組相容的 plugin（日後可記進發佈清單）、官方 plugin 集中好找。

- 範圍：現有六個官方 plugin（`battery`、`google-maps`、`haptics`、`mirror-demo`、`sqlite-drift`、`file-manager`）與尚未 push 的 `secure-storage`（本機有 2 個 commit）。之後的 `biometrics`、`location` 直接在這個 repo 裡開。
- **保留 git 歷史**：用 `git subtree add` 把各 repo 併進去，不重寫歷史。
- **安裝方式不變**：plugin id、npm 套件名（`aqutter-plugin-<id>`）、Dart 套件名都不改；使用者仍然 `aqutter plugin add aqutter-plugin-haptics`（npm 套件名），或從 GitHub 直接裝單一 plugin：`aqutter plugin add "github:Aqutter/aqutter-plugins#path:/packages/haptics"`（已驗證 pnpm 的 `#path:` 只安裝那個子資料夾）。
- 第三方與使用者自己寫的 plugin 照舊各自一個 repo，`aqutter plugin create` 範本不變。

## Architecture
- 根目錄：`pnpm-workspace.yaml`（`packages/*`）、`package.json`（私有，放共用 script）、`README.md`（官方 plugin 清單與安裝方式）、`AGENTS.md`、`.gitignore`、`.kn-project/`（整個 repo 一份治理文件）。
- 每個 plugin 在 `packages/<id>/`，內容與原 repo 根目錄相同：`aqutter-plugin.json`、`package.json`、`pubspec.yaml`、`lib/`、`src/`、`test/`、`README.md`、必要的原生目錄。
- **治理文件合併**：各 repo 的 `.kn-project/archive/*` 搬到根目錄 `.kn-project/archive/`（檔名是唯一的時戳編號，不會撞名）；`plans/` 底下進行中的計畫（file-manager、secure-storage）搬到根目錄 `.kn-project/plans/`；各 repo 的 `project.md` 不保留（根目錄另寫一份）。
- **共用 script**：根目錄 `pnpm typecheck`（`pnpm -r typecheck`）與 `pnpm test:dart`（逐個 package 跑 `flutter test`），讓一個指令驗證全部。
- **併入前先確認各 repo 乾淨且已 push**：file-manager 的 commit 已在 GitHub；secure-storage 還沒 push，本機的 2 個 commit 會隨 subtree 進來，不需要先建遠端 repo 的內容。

## Cross-Repo Scope
- **本計畫所屬 repo**: `aqutter-plugins`（新建）
- **共用計畫 ID**: `2611021545-official-plugins-monorepo`；各 repo 直接 `main`。
- **參與 repo 與職責**:
  - `aqutter-plugins` — 合併、工具、文件（本計畫主體）。
  - `aqutter` — `docs/plugins.md` 的「官方 plugin」清單與安裝說明改指向新 repo、wiki 同步（另開同名小計畫）。
  - `aqutter-nuxt-app` — 七個 plugin 依賴改成新的安裝字串、重新驗證建置（另開同名小計畫）。
  - 舊的七個 plugin repo — 在新 repo 驗證完成**並經你同意後**，各放一個指向新 repo 的 README 並設為封存（archive）；不刪除。
- **執行順序相依**: 新 repo 建立並 push → 範例 App 與文件改用新字串、驗證 → 才處理舊 repo。
- **不在本計畫**: 「不支援的平台不再報錯」的框架行為變更（另一份計畫，建議等本計畫完成後做，因為它會一次改到所有官方 plugin 的網頁 API）。

## Contract / 介面契約
- **契約正本 repo**: `aqutter-plugins`　**修訂號**: `rev 1`　**狀態**: `草擬`

### 1. 安裝字串（消費方：`aqutter plugin add`、範例 App 的 `package.json`、文件）
| 來源 | 字串 |
|---|---|
| npm（發佈後） | `aqutter-plugin-<id>` |
| GitHub 單一 plugin | `github:Aqutter/aqutter-plugins#path:/packages/<id>` |
| 本機開發 | `file:../aqutter-plugins/packages/<id>` |

### 2. 不變的識別
| 項目 | 規則 |
|---|---|
| plugin id | 不變（`battery`、`google-maps`、`haptics`、`mirror-demo`、`sqlite`、`file-manager`、`secure-storage`） |
| npm 套件名 | 不變（`aqutter-plugin-<id>`；sqlite 是 `aqutter-plugin-sqlite-drift`） |
| Dart 套件名與類別 | 不變 |
| `aqutter.config.json` 登記的 `npm` 欄位 | 不變，既有 App 的 `plugin sync` 不受影響 |

### 3. 相容性
- 既有 App 的 `package.json` 若仍寫 `github:Aqutter/aqutter-plugin-<id>`，在舊 repo 還在（封存後仍可 clone）的情況下繼續可用；新 App 與文件一律用新字串。
- 舊 repo 封存後不再接收更新；要新功能必須改用新字串。

### 4. 變更紀錄
- _(尚無)_

## Impact Files
- `pnpm-workspace.yaml`、`package.json`、`README.md`、`AGENTS.md`、`.gitignore`（皆 new）— 根目錄骨架
- `packages/<id>/**`（new，七個）— 來自各舊 repo 的 `git subtree add`，內容不改
- `scripts/test-dart.mjs`（new）— 逐 package 跑 `flutter test`
- `.kn-project/archive/*`、`.kn-project/plans/*`、`.kn-project/project.md`（皆 new）— 合併後的治理文件
- 各 `packages/<id>/pubspec.yaml`（既有，subtree 帶入）— **不改**：它們依賴殼的 git ref，與位置無關

## Open Questions / 待確認事項
### Q1. repo 名稱 — 影響範圍：新 repo、安裝字串
- [ ] `aqutter-plugins`（建議：直觀，符合現有 `aqutter-*` 命名）
- [ ] `aqutter-official-plugins`
- **決議**：_(待確認)_　狀態：⏳ 待確認

### Q2. 舊 repo 的處理 — 影響範圍：七個舊 repo
- [ ] 新 repo 驗證完成後，在舊 repo 放一個指向新 repo 的 README 並設為封存（archive），不刪除（建議：可逆，既有連結仍可 clone）
- [ ] 只放 README，不封存
- [ ] 保持原狀、不處理
- **決議**：_(待確認)_　狀態：⏳ 待確認

### Q3. 是否現在就把 `sqlite-drift` 與其他 plugin 一併遷入 — 影響範圍：`packages/`
- [ ] 全部七個一次遷入（建議：一次到位，之後只維護一個地方）
- [ ] 先遷入已維護中的（file-manager、secure-storage），其餘之後再說
- **決議**：_(待確認)_　狀態：⏳ 待確認

## Manual Follow-ups / 人工收尾事項
- **[合併後]** 發佈到 npm（若要讓使用者用 `aqutter plugin add aqutter-plugin-<id>` 的短字串）— 需要 npm 帳號與 token，每個套件 `pnpm publish` — agent 不持有 npm 憑證，也不該代發佈。在發佈前，用 GitHub 子資料夾字串安裝即可。
- **[合併後]** 在 GitHub 把舊的七個 repo 設為封存（若選擇封存）— 屬對外且影響其他人的設定，需你確認後我才執行。
- **[上線前]** 範例 App 以外的既有 App（若有）把依賴改成新字串 — 屬各 App 擁有者。

## Key Decisions
- **[合併]** 官方 plugin 合併成單一 repo、安裝仍可用單一 plugin（使用者決定）。
- **[時機]** 先遷移再繼續開發 `secure-storage`、`biometrics`、`location`（使用者選擇）。
- **[歷史]** 用 `git subtree add` 保留各 repo 歷史，不重寫。
- **[安裝]** 用 pnpm 的 `#path:` 子資料夾安裝，不需要先發佈到 npm；實測 pnpm 只安裝指定的子資料夾。
- **[流程]** 直接 main、不建 issue（待核准時確認）。

## Git Completion Policy
- commit 自動；建立遠端 repo、push、封存舊 repo 依核准閘與 Open Questions 的決議，逐項確認。

## References
- `aqutter/docs/plugins.md`（官方 plugin 清單與安裝）、`aqutter-cli/src/commands/plugin.ts`（`plugin add` 以前後依賴差判斷套件名）
