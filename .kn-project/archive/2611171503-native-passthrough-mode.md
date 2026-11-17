# 2611171503-native-passthrough-mode

- Created: 2026-11-17 / Archived: 2026-11-17
- Issue: Aqutter/aqutter-plugins#8
- Milestone: N/A / Base Branch: main

## Summary
google-maps plugin 新增 `mode` 選項（Dart 的 `GoogleMapsPlugin(mode:)` 與網頁的 `googleMaps.mount(el, { mode })`），讓原生地圖用鏡像或穿透顯示，事件與手勢兩種模式共用。
穿透由 core 提供，plugin 不自己實作：`mode` 傳給 `AqutterNative(mode:)` 與 `<aqutter-native mode>`；地圖只占畫面一部分（`widthFactor`／`heightFactor` ≠ 1）時一律鏡像。README 新增「顯示模式」章節。

## Cross-Repo Scope
- **本計畫所屬 repo**: `aqutter-plugins`
- **共用計畫 ID**: `2611171503-native-passthrough-mode`　**共用分支名**: `feature/2611171503-native-passthrough-mode`
- **參與 repo 與職責**（一 repo 一 issue，尚未建立時寫 `待建立`）:
  - `aqutter_core` — 契約正本；協定的原生端、`AqutterNative` widget、`passthroughSessions`、Android WebView 透明的行為保證　issue: `Aqutter/aqutter_core#31`
  - `aqutter-js` — 標籤的 `mode` 屬性、模式協商、頁面可穿透偵測、`layout` 追蹤、`aqutter-mode` 事件　issue: `Aqutter/aqutter-js#14`
  - `aqutter` — 殼：監聽 `passthroughSessions` 切換 WebView 透明　issue: `Aqutter/aqutter#68`
  - `aqutter-plugins` — google-maps 等 plugin 沿用同一個標籤與 `AqutterNative`，加上 `mode` 選項、文件　issue: `Aqutter/aqutter-plugins#8`
- **執行順序相依**: `aqutter_core`（協定與 Dart 端）先；`aqutter-js` 在契約凍結後可與 core **平行**（兩端以契約為準，整合驗證需等兩邊都完成）；`aqutter`（殼）與 `aqutter-plugins` 需等待 `aqutter_core` 的 `passthroughSessions` 與透明行為保證完成，plugin 另需等待 `aqutter-js`。
- **跨 repo 檔案指涉**: 無（各 repo 的檔案只列在自己的 `## Impact Files`）。
- **合併後的連動**: 各 repo 合併後，`aqutter` 的 `manifest/releases.json`（`core.ref`、`shell.ref`、`client.spec`）與 `aqutter-cli` 的 manifest 快照需重新同步，0.0.0 tag 需移動，見各份 `## Manual Follow-ups`。
- **契約**：正本 `aqutter_core`，最終 rev 2；介面共 9 項（`mode` 屬性、`mode` 請求與回覆、`layout`、手勢訊息不變、`AqutterNative(mode:)`、`passthroughSessions`、`aqutter-mode` 事件、WebView 透明的行為保證）；全文在 aqutter_core 的 archive 與 PR 說明。

## Key Decisions
- **[Phase 0]** 目標 repo：`aqutter_core`、`aqutter-js`、`aqutter`、`aqutter-plugins`（依據：鏡像實作在 `aqutter_core/lib/src/nativeview/` 與 `aqutter-js/src/nativeview/`；殼的底層與 WebView 在 `aqutter/shell/lib/src/app.dart`；使用端在 `aqutter-plugins/packages/google-maps`）。`aqutter-cli`、`aqutter-nuxt-app` 不在本次範圍（只有合併後的鎖定同步）。
- **[Milestone]** 四個 repo 皆不指定，以 `main` 為 base — 使用者於 Phase 0 選擇。
- **[Q1]** 預設 `mode` 為 `auto` — 使用者決議；已知會改變既有 Android App 的行為，以 `pageReady` 偵測降低風險（契約 §5）。
- **[Q2]** iOS 的 `auto` 先視為不支援 — 理由：沒有 iOS 設備，未驗證。
- **[設計]** 模式決策只在原生端；網頁只回報 `pageReady`。 — 理由：兩端各自決策會不一致。
- **[設計]** 手勢座標維持相對元素 0..1。 — 理由：plugin 的手勢處理不需修改；穿透時原生端以元素大小的 child 承接。
- **[設計]** 底層原生內容與元素同大、同位置（不是螢幕大小）。 — 理由：前置實驗證實螢幕大小的地圖在元素一開始在螢幕外時，捲進來會是空白。
- **[設計]** 殼的 WebView 透明依 `passthroughSessions` 動態切換，不是全域常開。 — 理由：避免啟動時與其他畫面露出底層。
- **[前置實驗]** 透明的初始設定在 Android 不生效（兩段式才生效），列為 aqutter_core 要查根因的工作，不在殼繞過。
- **[程式碼風格]** 實作遵守 `kn-project-code-style`。
- **[契約]** rev 1 凍結（核准日 2026-11-17）。
- **[契約變更]** rev 1 → rev 2（已核准）：child 一律保持掛載，穿透時第一則可見 layout 前以 `Offstage` 隱藏（契約 §4、§6）；只影響 aqutter_core 的實作，本 repo 只同步契約文字。
- **[實作]** `GoogleMapsPlugin(mode:)` 傳給 `AqutterNative(mode:)`；只占畫面一部分（`widthFactor`／`heightFactor` ≠ 1）時一律鏡像——穿透時地圖與位置跟著網頁元素，而 `AqutterNative` 的盒子原點必須等於 WebView 視窗原點（契約 §4），`FractionallySizedBox` 包住它會讓矩形換算錯位。`GoogleMapsMountOptions.mode` 設到元素的 `mode` 屬性，省略時不設（元素預設 `auto`）。
- **[實作]** Android 維持原本強制的 texture 模式（`useAndroidViewSurface = false`）：前置實驗與整合驗證都是在 texture 模式下通過的，Hybrid Composition 模式沒有測。
- **[驗證]** Dart 17 個、TypeScript 27 個測試通過；整合驗證（core＋js＋殼）時用的是**未修改**的 plugin：預設 `auto` 協商成穿透、屬性切 `mirror`／`passthrough` 都正確。`mode` 選項設屬性靠單元測試，`GoogleMapsPlugin(mode: mirror)` 強制鏡像未在實機驗證（core 的決策表測試涵蓋 `unsupported-widget`）。
- **[教訓]** 整合驗證時在 nuxt-app 的 `node_modules` 原地覆蓋檔案，pnpm 的 hardlink 讓共用內容被改到，其他專案的 `@aqutter/aqutter` 因此少了新檔案而型別檢查失敗；已還原。之後要覆蓋 `node_modules` 內的檔案須先刪除再複製（建立新 inode）。
- **[完成後]** commit + 開 PR（Rule 12 非互動鏈；完成前自動 fetch 後 rebase origin/main 並 push --force-with-lease --force-if-includes）。
- **[執行模式]** 序列（依據：環境只有單一 agent，沒有獨立子 agent）；順序 aqutter_core → aqutter-js → aqutter → aqutter-plugins。
- **[範圍]** 使用者指示「先定契約」：本次先把契約凍結、建立 issue 與分支並提交計畫，實作（`tasks.md` 的 Phase 1 起）等使用者確認後再開始。

## Deviations
- **契約 rev 1 → rev 2**：只同步契約文字，plugin 的程式不受影響。
- **只占畫面一部分的地圖一律鏡像**（計畫未寫）：穿透時地圖的大小與位置跟著網頁元素，而 `AqutterNative` 的盒子原點必須等於 WebView 視窗原點，`FractionallySizedBox` 包住它會讓矩形換算錯位。
- **前置實驗的 plugin 層實作不併入**：`show`／`hide`／`layout`／`gesture` handler 與兩個編譯期鍵由 core 取代（實驗分支 `feature/2611171140-map-passthrough-spike` 保留，其驗證報告在該分支）。
- **Android 維持強制 texture 模式**：實驗與整合驗證都在 texture 模式下通過，Hybrid Composition 沒測。
- **沒有 wiki**：本 repo 沒有 `.kn-project/wiki`，未建立。
- `GoogleMapsPlugin(mode: mirror)` 強制鏡像未在實機驗證（core 的決策表測試涵蓋 `unsupported-widget`）；`mode` 選項設屬性靠單元測試。
- 整合驗證時在 nuxt-app 的 `node_modules` 原地覆蓋檔案，pnpm 的 hardlink 讓共用內容被改到，造成本 repo 型別檢查失敗；已還原，之後覆蓋須先刪除再複製。

## Impact Files
- `packages/google-maps/lib/src/google_maps_plugin.dart:32` (`GoogleMapsPlugin` 建構子)、`:161` (`buildUnderlay`) — 新增 `mode`，傳給 `AqutterNative`。
- `packages/google-maps/src/nativeProvider.ts:12` (`createNativeView`)、`packages/google-maps/src/view.ts:21` (`GoogleMapsMountOptions`) — 新增 `mode` 選項，設到 `<aqutter-native>` 的 `mode` 屬性。
- `packages/google-maps/test/google_maps_plugin_test.dart`、`packages/google-maps/test/index.test.ts` — 補 `mode` 的測試。
- `packages/google-maps/README.md` — 說明兩種模式、`mode` 選項與穿透的頁面條件。
- `packages/mirror-demo/` — 若其 plugin 需要暴露 `mode`，實作時確認；目前沒有佐證要動，不列入。
