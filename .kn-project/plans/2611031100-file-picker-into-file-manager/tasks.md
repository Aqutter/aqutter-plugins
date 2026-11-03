# Tasks for 2611031100

## Phase 1 — Dart 端
- [x] [aqutter-plugins] 讀 `location.dart` 與既有測試，確認位置解析與假物件寫法
- [x] [aqutter-plugins] 新增 `PickedRegistry` 與可注入的選檔器
- [x] [aqutter-plugins] `FileManagerPlugin` 新增 `pick`，並讓 `picked:` 位置只能讀（stat／read／copy 來源）
- [x] [aqutter-plugins] Dart 單元測試（取消、單選、多選、副檔名過濾、寫入被拒、失效編號）

## Phase 2 — 網頁端與文件
- [x] [aqutter-plugins] `src/index.ts` 契約與 `fileManager.pick`、型別與測試
- [x] [aqutter-plugins] README 與契約說明更新

## Phase 3 — 驗證
- [x] [aqutter-plugins] `pnpm verify`（typecheck、test、test:dart）通過
- [x] 需等待 [aqutter-nuxt-app]：Android／Windows 實機驗證
