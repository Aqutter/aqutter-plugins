# 2611142300-google-maps-spm-evaluation

- Created: 2026-11-14 23:00 / Archived: 2026-11-15 00:00
- Issue: Aqutter/aqutter-plugins#3
- Milestone: N/A / Base Branch: main

## Summary
評估 `google_maps_flutter_ios` 不支援 Swift Package Manager 的處理方式：結論是它設計上就不會支援 SPM，官方路徑是改用 SDK 專用實作套件，建議採用 `google_maps_flutter_ios_sdk9`（iOS 15+），已在 nuxt-app 的 iOS 模擬器實測 SPM 與 CocoaPods 兩條路徑都可用。

本計畫只做評估與暫存試作，不改 `aqutter-plugins` 的程式碼；實際採用另案處理，建議在 2026-12-02（CocoaPods registry 唯讀）前完成。

## Cross-Repo Scope
`aqutter-plugins`（擁有 `google-maps`）為主；`aqutter-nuxt-app` 只作驗證用 App（暫時覆寫依賴、已還原、無提交）；上游 `flutter/packages` 只讀、未寫入。

## Key Decisions
- **[Q1]** 包含實際試作（暫存目錄，不進版控）— 理由：直接回答 SPM 相依相容性與兩條路徑是否可跑
- **[Q2]** 使用者回答「沒有 issue 就先不處理」：不對上游 `flutter/packages` 寫入，也不準備 issue 草稿，報告只記錄上游追蹤現況 — 理由：對公開 repo 發言不可收回，且須用使用者身分
- **[核准]** 使用者核准；完成後採預設 commit + 開 PR；沿用 issue #3。
- **[Phase 0]** 單一 repo `aqutter-plugins`；綁定既有 issue `Aqutter/aqutter-plugins#3`（沿用，不新開）；已 sync 至 `origin/main` 且工作區乾淨。
- **[Phase 0]** Milestone：不指定（使用者回答）；Base Branch = `main`。
- **[Phase 0]** 整合主幹：遠端無 dev／develop 類分支，採 `origin/HEAD`＝`main`，不詢問、不記錄。
- **[範圍]** 只評估，不改 plugin 程式碼；不對上游寫入。
- **[執行模式]** 序列（單一 repo）。
- **[結論]** `google_maps_flutter_ios` 設計上無法支援 SPM（上游 README：SPM 無法依最低部署目標選 Google Maps SDK 版本），且不再有新功能；官方路徑是 SDK 專用實作套件。議題原假設「等上游加 `Package.swift`」不成立，已在 issue 更正。建議採用 `google_maps_flutter_ios_sdk9`（iOS 15+），nuxt-app 部署目標 15.0 吻合。
- **[實測]** nuxt-app iOS 模擬器（Flutter 3.50.0）：SPM 路徑建置成功且無「不支援 SPM」警告、地圖顯示與 Satellite 切換正常；CocoaPods 路徑（SPM 關閉）建置也成功（`_sdk9` 兩者皆支援）；`AppDelegate.swift` 不需修改。驗完 nuxt-app 與 Flutter 設定已還原。
- **[發現]** 換到 `_sdk9` 時殘留的 CocoaPods 建置產物會造成 `2083 duplicate symbols`（GoogleMapsUtils 重複），`flutter clean` 並刪 `ios/Pods`、`Podfile.lock` 即解。
- **[更正]** 我先前曾推測 `_sdk9` 只走 SPM，是看錯目錄層級；實測與目錄確認它有 podspec，兩條路徑都可用。
- **[採用方式]** 依上游建議，套件作者不依賴 `_sdk*`，改由應用程式選擇：`packages/google-maps/pubspec.yaml` 不加，README 說明，nuxt-app 採用（需另案）。
- **[時程]** CocoaPods spec registry 2026-12-02 唯讀；上游未給 Flutter 把警告升為 error 的日期。
- **[Q2 執行]** 依使用者決定未對上游寫入，也未準備草稿；上游方向已在其 README 文件化，亦不需要追蹤 issue。
- **[未驗證]** 實體 iOS 裝置與簽章；`_sdk10`；SPM 首次解析需連 GitHub（CI／離線）。

## Deviations
試作方式與計畫不同：計畫預設「在暫存目錄為 `google_maps_flutter_ios` 加 `Package.swift`」，Phase 1 研究發現上游設計上不支援，改為驗證官方的 SDK 專用套件 `_sdk9`。Phase 2 的三項（SPM 開、地圖顯示、SPM 關）都以 `_sdk9` 完成。不準備上游 issue 草稿（依 Q2）。

## Impact Files
無（評估計畫，不修改 repo 檔案；僅歸檔本檔與 issue #3 留言）。
