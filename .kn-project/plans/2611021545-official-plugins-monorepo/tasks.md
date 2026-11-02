# Tasks for 2611021545

## Phase 1 — 合併
- [ ] 確認 Open Questions 與契約凍結
- [ ] 根目錄骨架（workspace、script、README）
- [ ] 逐個 `git subtree add` 併入七個 plugin，確認歷史與檔案完整
- [ ] 治理文件合併到根目錄 `.kn-project/`

## Phase 2 — 驗證
- [ ] `pnpm install`、`pnpm typecheck`、`pnpm test:dart` 全部通過
- [ ] 用 `#path:` 字串在暫時專案實測 `aqutter plugin add`

## Phase 3 — 發佈與切換
- [ ] 建立遠端 repo 並 push（需確認）
- [ ] 範例 App 的依賴改新字串並重新建置驗證
- [ ] `aqutter` 文件與 wiki 改指向新 repo
- [ ] 舊 repo 的 README 與封存（需確認）
