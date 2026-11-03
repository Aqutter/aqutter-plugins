# 2611031100 - file-picker-into-file-manager

- Created: 2026-11-03 11:00 / Archived: 2026-11-03
- Issue: N/A（本專案開發階段不建 issue）
- Milestone: N/A / Base Branch: main

## Summary
`file-manager` plugin 新增一次性選檔 `pick(kind, {extensions, title})`，選到的檔案以只讀的 `picked:<編號>` 位置交給網頁，之後用既有的 `stat`／`read`／`copy` 操作，取代內建 `picker_pick`。編號只存在記憶體、不進 `grants`、App 重啟即失效。本 repo 是契約提供方；殼 `aqutter` 的 `picker_pick` 與 `file_picker` 依賴本輪不動。

## Cross-Repo Scope
- 共用計畫 ID `2611031100-file-picker-into-file-manager`；各 repo 直接 `main`，無共用分支。
- `aqutter-plugins`（本 repo，契約提供方）→ 先做；`aqutter-js`（內建型別標記棄用）、`aqutter-nuxt-app`（示範頁改用 `pick`）之後，nuxt-app 需要本 repo 的新 commit。
- 不在本計畫：殼 `aqutter` 移除 `picker_pick` 與 `file_picker` 依賴（破壞性，等棄用版本發佈後另案）。

## 契約（只留引用）
正本是 `packages/file-manager/src/index.ts`（`pick`、`PickedFile`）與 `README.md`，rev 1，凍結後無變更。方法 `pick`；錯誤碼新增 `invalid_argument`，並使用 `permission_denied`、`not_found`；`picked:` 只能讀（`stat`、`read`、`copy` 來源、`saveToDownloads` 的 `from`），不支援平台網頁端回 `[]`。

## Key Decisions
- **[Q1]** 新增一次性 `pick`，`grant` 不變 — `grant` 在 Android 只支援資料夾，且會持久保存授權；一次性選檔不該進授權清單。
- **[Q2]** 本輪不動殼 — 移除 `picker_pick` 對所有現有 App 是破壞性變更，先棄用、下一版再移除。
- **[執行中]** 位置字串只認 `picked:<編號>`、不含子路徑；從 picked 複製以 5 MiB 分段讀寫完成，目的端可能是 SAF。
- **[驗證]** Dart 79 個與網頁端測試通過；Windows 與 Android（Zenfone 8）實機經 nuxt-app 驗證選單檔與讀取；Windows 驗過取消。

## Deviations
- 無契約變更。
- 未驗證：iOS／macOS 的 `pick`（macOS 沙盒需 entitlement `com.apple.security.files.user-selected.read-only`，已寫入 `aqutter-plugin.json` 與 README）；多選只有測試、未在實機走過；Android 取消未走過。

## Impact Files
- `packages/file-manager/lib/src/file_manager_plugin.dart:85`（方法分派）、`:139`（`grant` 處理器旁新增 `pick`）、`:185-207`（`_Target` 與位置解析加 `readOnly`／`picked:`）
- `packages/file-manager/lib/src/location.dart:53-70` — `picked:` 前綴、`errInvalidArgument`
- `packages/file-manager/lib/src/picked_registry.dart`（新）— `FileChooser`、`PickedRegistry`
- `packages/file-manager/src/index.ts:39`、`:67` — `pick` 契約、`PickedFile`、`fileManager.pick`
- `packages/file-manager/aqutter-plugin.json` — `pick` 功能與 macOS 備註
- `packages/file-manager/test/file_manager_plugin_test.dart`、`test/pick.test.ts`（新）、`test/unsupported.test.ts`
- `packages/file-manager/README.md`
