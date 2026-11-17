<!-- Relative paths only -->
# Plan: 2611171503 - native-passthrough-mode
- Created: 2026-11-17
- Branch: feature/2611171503-native-passthrough-mode
- Issue: Aqutter/aqutter-plugins#8
- Milestone: N/A（未指定）
- Base Branch: main
- Status: In Progress
- Completed: [Wait for Finish]

## Goals
google-maps（以及使用 `<aqutter-native>` 的 plugin）沿用 core 的穿透模式：不需要自己實作穿透。google-maps 加上 `mode` 選項（對應標籤屬性與 `AqutterNative(mode:)`），文件說明兩種模式與頁面條件。前置實驗的 plugin 層實作（`show`／`hide`／`layout`／`gesture` handler 與兩個編譯期鍵）不併入，由 core 取代。

## Architecture
- 現況（main）：`GoogleMapsPlugin.buildUnderlay` 把 `GoogleMap` 包在 `AqutterNative` 裡（`packages/google-maps/lib/src/google_maps_plugin.dart:161`）；網頁端 `createNativeView` 建立 `<aqutter-native>`（`packages/google-maps/src/nativeProvider.ts:12`）。
- 變更：Dart 端建構子加 `mode`，傳給 `AqutterNative`；網頁端 `GoogleMapsMountOptions.mode` 設到元素的 `mode` 屬性；穿透時不強制 Android texture 模式的限制若與穿透衝突，於實作時依實測決定並記入 Key Decisions（實驗是在 texture 模式下通過的）。
- 程式碼風格：遵守 `kn-project-code-style`（Dart、TypeScript）。

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

## Contract / 介面契約
- **契約正本 repo**: `aqutter_core`　**修訂號**: `rev 2`　**狀態**: `凍結（核准日 2026-11-17；rev 2 核准日 2026-11-17）`

目標：`<aqutter-native>` 除了現有的鏡像（`mirror`），新增穿透（`passthrough`）：原生內容直接畫在透明 WebView 下面，標籤只佔版面、不畫 canvas；兩種模式共用同一個標籤、同一組手勢與事件，用 `mode` 屬性切換。

### 1. 介面清單
| # | 介面 | 所屬 | 方向 | 用途 |
|---|---|---|---|---|
| 1 | `<aqutter-native mode="mirror｜passthrough｜auto">` 屬性 | aqutter-js | 網頁作者 → 元素 | 選擇顯示模式；預設 `auto` |
| 2 | WS 文字訊息 `{"type":"mode",...}`（請求） | aqutter-js → aqutter_core | 網頁 → 原生 | 連線後的第一則訊息，請求模式並回報頁面是否可穿透 |
| 3 | WS 文字訊息 `{"type":"mode",...}`（回覆） | aqutter_core → aqutter-js | 原生 → 網頁 | 回報實際生效的模式與原因 |
| 4 | WS 文字訊息 `{"type":"layout",...}` | aqutter-js → aqutter_core | 網頁 → 原生 | 穿透模式下回報元素的矩形 |
| 5 | 手勢與指令訊息 `tap／doubleTap／longPress／pan／pinch／pointer／command` | 既有 | 網頁 → 原生 | **不變**；座標仍是相對元素的 0..1 |
| 6 | `AqutterNative(mode: AqutterNativeMode)` 參數 | aqutter_core（Dart） | App／plugin → widget | 宣告這個 widget 允許哪些模式；預設 `auto` |
| 7 | `AqutterNativeHost.instance.passthroughSessions`（`ValueListenable<int>`） | aqutter_core（Dart） | 原生內部 → 殼 | 目前生效為穿透的工作階段數；殼據此切換 WebView 透明 |
| 8 | CustomEvent `aqutter-mode` | aqutter-js | 元素 → 頁面 | 模式確定後通知，`detail: { mode, reason? }` |
| 9 | `AqutterWebViewController.setSettings(transparentBackground)` 的行為保證 | aqutter_core（Dart／Android） | 殼 → WebView | 呼叫後 WebView 底色確實變透明／不透明（含初次與執行期） |

### 2. 欄位
**#1 `mode` 屬性**
| 值 | 說明 |
|---|---|
| `auto`（預設） | 平台支援、widget 允許、且頁面可穿透時用穿透，否則用鏡像 |
| `mirror` | 一律鏡像（現有行為） |
| `passthrough` | 要求穿透；平台或 widget 不支援時退回鏡像並回報原因；**不做頁面可穿透偵測**（頁面作者自負責任） |
- 不合法的值：視為 `auto`，並 `console.warn` 一次。屬性可在執行期改變：等同 `session` 改變，元素重新連線並重做模式協商（現有 `restart()`）。

**#2 `mode` 請求**（JSON，文字訊息）
| 欄位 | 型別 | 必填 | 說明 |
|---|---|---|---|
| `type` | `"mode"` | 是 | |
| `request` | `"auto"｜"mirror"｜"passthrough"` | 是 | 元素目前的 `mode` 屬性值 |
| `pageReady` | boolean | 是 | 網頁偵測的「頁面可穿透」：元素往上到 `<html>` 的每個祖先，`background-color` 的 alpha < 0.99 且 `background-image` 為 `none`。`request` 為 `passthrough` 時仍送出，但原生端不採用 |

**#3 `mode` 回覆**
| 欄位 | 型別 | 說明 |
|---|---|---|
| `type` | `"mode"` | |
| `mode` | `"mirror"｜"passthrough"` | 實際生效的模式 |
| `reason` | 字串，選填 | 與請求不同時才有：`unsupported-platform`、`unsupported-widget`、`page-not-ready`、`transparent-failed` |

**#4 `layout`**
| 欄位 | 型別 | 必填 | 單位／限制 |
|---|---|---|---|
| `type` | `"layout"` | 是 | |
| `left`、`top` | number | 是 | CSS px，`getBoundingClientRect()`，相對 WebView 視窗左上角 |
| `width`、`height` | number | 是 | CSS px，≥ 0 |
| `visible` | boolean | 是 | 元素未渲染、`display:none`、寬或高為 0、或頁面不可見時為 `false` |
| `sentAt` | number | 否 | 送出時的 epoch 毫秒，供原生端量延遲 |
- 送出時機：回覆 `mode: passthrough` 後立刻送一次；之後元素大小、位置（任何祖先捲動、視窗大小改變）變動時送，**每個動畫畫面最多一則**。原生端忽略與上一則相同的內容。

**#6 `AqutterNativeMode`**：`auto`（預設）、`mirror`、`passthrough`。這是 widget 端的**允許範圍**：`mirror` 表示絕不穿透；`passthrough`、`auto` 表示允許穿透（仍受平台限制）。

**#7 `passthroughSessions`**：`ValueListenable<int>`，≥ 0，工作階段的生效模式變成／不再是穿透時增減，連線關閉時扣回。

**#8 `aqutter-mode`**：`CustomEvent`，不冒泡，`detail.mode` 為生效模式，`detail.reason` 同 #3。

### 3. 失敗與退回（取代錯誤碼）
| reason | 觸發條件 | 行為 |
|---|---|---|
| `unsupported-platform` | 非 Android（iOS 待實機驗證前視為不支援；macOS、Windows、Linux、Web） | 生效模式 `mirror`；`request` 為 `passthrough` 也一樣退回 |
| `unsupported-widget` | widget 的 `mode` 為 `mirror` | 生效模式 `mirror` |
| `page-not-ready` | `request` 為 `auto` 且 `pageReady` 為 false | 生效模式 `mirror` |
| `transparent-failed` | 殼無法使 WebView 透明（`setSettings` 失敗） | 生效模式 `mirror` |
| （無回覆） | 網頁送出請求後 1000 ms 內沒收到回覆（舊版原生端） | 網頁端退回 `mirror`，照舊開始收幀；觸發 `aqutter-mode`，`reason: "no-reply"` |

### 4. 狀態與規則
- **決策只在原生端**：生效模式 = 請求 ∩ widget 允許 ∩ 平台支援 ∩（`auto` 時）`pageReady`；網頁端只負責回報 `pageReady`。
- **模式在工作階段開始時決定一次**，執行期改變一律走重新連線；原生端的 child 在重新連線期間保持掛載，不重建（穿透 ↔ 鏡像的切換只是「開始／停止擷取」與「child 是否被定位」）。
- **鏡像**：行為與現在完全相同。
- **穿透**：不擷取、不送幀（`ack` 忽略）；元素的 shadow DOM 不建立 `<canvas>`，`fit`、`max-in-flight` 屬性忽略；`input`、`double-tap*`、`slop`、`long-press-ms` 屬性照常生效，手勢辨識沿用現有 `GestureRecognizer`；host 的 `touch-action: none` 維持。
- **原生端的版面**：`AqutterNative` 的盒子原點必須等於 WebView 視窗原點（例如殼的底層 `Stack` 中的 `Positioned.fill`）；穿透時依 `layout` 把 child 以緊約束（`width × height`）放在 (`left`, `top`)。**child 從 widget 第一次建立起就保持掛載**：工作階段開始時尚未協商出模式，一律先當鏡像，child 照常建立；協商成穿透後，第一則 `visible: true` 的 `layout` 到達前、以及 `visible: false` 時，child 仍保持掛載但不繪製（`Offstage`），不重建、不遺失狀態。
- **手勢座標**：相對元素盒子的 0..1，與鏡像相同，所以 plugin 的手勢處理（例如地圖的 pan／pinch）不需修改。
- **WebView 透明**：殼監聽 `passthroughSessions`，大於 0 時把 WebView 設為透明、回到 0 時還原不透明；只有穿透中才透明。多個穿透工作階段的上下順序依殼底層 `Stack` 的 plugin 順序，不屬契約。
- **頁面責任**：穿透時元素後方的祖先不得畫不透明背景；`auto` 以 `pageReady` 偵測（工作階段開始與 `mode` 屬性改變時各一次），`passthrough` 不偵測。
- `aqutter-status` 事件不變；`aqutter-frame` 只在鏡像出現。

### 5. 相容性
- **預設值 `auto` 會改變 Android 上的既有行為**：頁面祖先沒有不透明背景的既有 App 會自動改用穿透；有不透明背景的（偵測為 `page-not-ready`）維持鏡像。偵測只涵蓋祖先的 `background-color` 與 `background-image`，不涵蓋兄弟元素、偽元素、`box-shadow` 遮罩等，這些情況需要作者改用 `mode="mirror"`。
- 舊網頁＋新原生端：沒有 `mode` 請求的工作階段視為 `mirror`，原生端照舊運作。
- 新網頁＋舊原生端：網頁等 1000 ms 沒回覆就退回 `mirror`（多等 1 秒才開始收幀）。
- 幀標頭、手勢訊息、`resize`／`visibility`／`config`／`ack` 控制訊息**不變**（`native_frame.dart` 與 `nativeview/{frame,gestures}.ts` 成對規則不受影響）。
- 既有 plugin 的網頁 API 與事件不變；`googleMaps.element()` 在兩種模式都回標籤。

### 6. 變更紀錄
- **rev 2（2026-11-17，已核准）**：§4「原生端的版面」——child 一律保持掛載，穿透時在第一則可見的 `layout` 之前用 `Offstage` 隱藏，取代 rev 1 的「第一則 `visible: true` 的 `layout` 前不建立 child」。原因：rev 1 與「child 在模式切換期間保持掛載」自相矛盾；widget 在協商前先當鏡像建好 child，改成穿透時若拆掉重建，PlatformView（例如地圖）的狀態會遺失、並建立兩次（以 `initState` 計數的測試證實）。影響 repo：只有 `aqutter_core` 的實作；`aqutter-js`、`aqutter`、`aqutter-plugins` 的程式不受影響，只需同步契約文字。

## Impact Files
- `packages/google-maps/lib/src/google_maps_plugin.dart:32` (`GoogleMapsPlugin` 建構子)、`:161` (`buildUnderlay`) — 新增 `mode`，傳給 `AqutterNative`。
- `packages/google-maps/src/nativeProvider.ts:12` (`createNativeView`)、`packages/google-maps/src/view.ts:21` (`GoogleMapsMountOptions`) — 新增 `mode` 選項，設到 `<aqutter-native>` 的 `mode` 屬性。
- `packages/google-maps/test/google_maps_plugin_test.dart`、`packages/google-maps/test/index.test.ts` — 補 `mode` 的測試。
- `packages/google-maps/README.md` — 說明兩種模式、`mode` 選項與穿透的頁面條件。
- `packages/mirror-demo/` — 若其 plugin 需要暴露 `mode`，實作時確認；目前沒有佐證要動，不列入。

## App-Flow Screens
（無 app-flow.json，略）

## Open Questions / 待確認事項
### Q1. 預設 `mode` — 影響範圍：aqutter_core、aqutter-js
- [x] `auto`（使用者決議）　(原建議維持 `mirror`；已在契約 §5 記錄對既有 App 的影響與 `pageReady` 偵測的涵蓋範圍)
- [ ] `mirror`
- **決議**：`auto`　狀態：✅ 已確認

### Q2. iOS 的 `auto` — 影響範圍：aqutter_core
- [x] 先視為不支援，退回 `mirror`　(建議，理由：iOS 沒有設備未驗證)
- [ ] 先視為支援
- **決議**：先視為不支援，退回 `mirror`　狀態：✅ 已確認

## Manual Follow-ups / 人工收尾事項
- **[合併後]** 更新 `aqutter-nuxt-app` 的 `aqutter-plugin-google-maps` 鎖定與 `aqutter` 鎖定（`pnpm-lock.yaml`、`pubspec.lock`）並重新同步 manifest — 依既有「鎖定升級」流程，需要使用者下指令 — 鎖定由使用者決定時機。

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

## Git Completion Policy
- PR 一律以 `--base main` 顯式指定 base，不依賴 `gh` 的預設值 (Rule 23)。
- Issue 綁定時，每個 commit 訊息與 PR body 都含 `Closes #${N}`（`${N}` 取自上方 `- Issue:`）。
- commit 一律自動；完成時依核准閘的「完成後」選項。
- 跨 repo 時，本 repo 自己開自己的 PR；建議合併順序見 `## Cross-Repo Scope`。

## References
- 前置實驗：`feature/2611171140-map-passthrough-spike`（`Aqutter/aqutter`、`Aqutter/aqutter-plugins`，不併入主幹），報告在 `aqutter-plugins` 該分支的 `.kn-project/plans/2611171140-map-passthrough-spike/report.md`。
