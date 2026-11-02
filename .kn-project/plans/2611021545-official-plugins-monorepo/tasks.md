# Tasks for 2611021545

## Phase 1 — 合併
- [x] 確認 Open Questions 與契約凍結
- [x] 根目錄骨架（workspace、script、README）
- [x] 逐個 `git subtree add` 併入七個 plugin，確認歷史與檔案完整
- [x] 治理文件合併到根目錄 `.kn-project/`

## Phase 2 — 驗證
- [x] `pnpm install`、`pnpm typecheck`、`pnpm test:dart` 全部通過
- [x] 用 `#path:` 字串在暫時專案實測 `aqutter plugin add`（CLI 正確辨識套件名並登記；暫時專案已刪除）

## Phase 3 — 發佈與切換
- [x] 建立遠端 repo 並 push
- [x] 範例 App 的依賴改新字串並重新建置驗證（Android release 建置與實機執行；七個 plugin 都從新 repo 安裝）
- [x] `aqutter` 文件與 wiki 改指向新 repo
- [ ] 舊 repo 的 README 與封存（需確認）
