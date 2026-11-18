# 2611181730-maps-inherit-radius

- Created: 2026-11-17 / Archived: 2026-11-17
- Issue: Aqutter/aqutter-plugins#10
- Milestone: N/A / Base Branch: main

## Summary
google-maps 的 `mount` 建立的 `<aqutter-native>` 預設加上 `border-radius: inherit` 與 `overflow: hidden`：穿透時背景洞的圓角（aqutter-js 取自元素本身）自然跟著容器，鏡像時元素自己裁掉 canvas 的四角。使用端只要替容器加圓角。
同時修剪 README 顯示模式一節：移除「圓角與遮罩要自己挖洞、祖先不可不透明」的舊說法，改寫為框架自動讓出背景（祖先透明、`data-aqutter-bg` 自動挖洞、`keep-background` 關閉）。新增 1 個單元測試。

## Cross-Repo Scope
- **本計畫所屬 repo**: `aqutter-plugins`
- **共用計畫 ID**: `2611181730-maps-inherit-radius`　**共用分支名**: `feature/2611181730-maps-inherit-radius`
- **參與 repo 與職責**:
  - `aqutter-plugins` — google-maps 元素繼承圓角、README　issue: `Aqutter/aqutter-plugins#10`
- **前置**：`aqutter-js` #17 已合併（提供自動挖洞與 `data-aqutter-bg`、`keep-background`）。本計畫的程式不依賴新版 client 才能運作（只是行內樣式），但 README 描述的行為需要新版 client。
- **後續（各自另案）**：`aqutter` manifest 與 `aqutter-cli` 快照重同步（含 `docs/nativeview.md` 修剪）；`aqutter-nuxt-app` 前進鎖定、移除展示頁補的 CSS、推上 main。

## Key Decisions
- **[Phase 0]** 單一 repo；Milestone 不指定；Base Branch = `main`；前例（passthrough 的 plugins 計畫）走 issue＋PR。
- **[Q1]** 不前進 client 依賴。
- **[Q2]** 單元測試；實機留到 nuxt-app 計畫。
- **[完成後]** commit + 推送 + 開 PR（base main）— 使用者核准。
- **[範圍]** 只改 google-maps 的網頁端與 README；其他 plugin（mirror-demo 等）不動。

## Deviations
- **實機驗證留到 nuxt-app 計畫**（計畫 Q2）：視覺已在 aqutter-js 計畫以頁面 CSS 的同一規則實機驗過。
- `pnpm verify` 第一次在 google-maps 的 Dart 測試編譯失敗，原因是本機被 gitignore 的 `pubspec.lock` 仍鎖在穿透模式之前的殼 commit（找不到 `AqutterNativeMode`），與本次改動無關；`flutter pub upgrade aqutter aqutter_core` 後 17 個 Dart 測試全過，TS 28 個測試全過。
- 未做：`@aqutter/aqutter` 開發依賴沒有前進（計畫 Q1 決議）。

## Impact Files
- `packages/google-maps/src/nativeProvider.ts:22-27` (`createNativeView`，`element.style.cssText`) — 加 `border-radius:inherit;overflow:hidden`。
- `packages/google-maps/test/index.test.ts:48` — 新增：元素行內樣式含 `border-radius: inherit` 與 `overflow: hidden`。
- `packages/google-maps/README.md:188-189` — 修剪過時說法（見 Architecture）。
