# Tasks for 2611021300

## Phase 1 — 契約與 sandbox
- [x] 確認 Open Questions 與契約凍結
- [x] 位置字串與路徑驗證（`location.dart`）
- [x] sandbox 操作（list、stat、read、write、makeDirectory、copy、move、delete）
- [x] 網頁端 API 與型別

## Phase 2 — gallery 與 downloads
- [x] 相簿（以 gal 實作；Dart 端與測試完成，未實機驗證）
- [x] 下載（改用系統另存視窗，契約 rev 2；Dart 端與測試完成，未實機驗證）
- [x] 描述檔 `native.features` 宣告（已用 CLI 的解析驗證）

## Phase 3 — granted
- [x] 授權清單持久化（shared_preferences，網頁無法經由 sandbox 位置竄改）
- [x] 桌面：grant、grants、revoke 與授權範圍內的操作（Dart 單元測試；只在 Windows 驗證）
- [ ] Android 樹狀授權（SAF；需在實機驗證）
- [ ] iOS bookmark、macOS 沙盒 bookmark（本機無法編譯驗證）

## Phase 4 — 驗證與文件
- [ ] 單元測試、`flutter analyze`
- [ ] README（範圍、不做清單、原生設定）
- [ ] 範例 App 接入與實機驗證（另開計畫）
