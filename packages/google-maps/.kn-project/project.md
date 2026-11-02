<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# aqutter-plugin-google-maps

Aqutter plugin（Dart 套件 + TypeScript 封裝），由 `aqutter plugin add github:Aqutter/aqutter-plugin-google-maps` 安裝到使用 Aqutter 的 App。詳見 [README.md](../README.md)。

## 保留鐵則

- **client 依賴來自 `Aqutter/aqutter-js`**：`package.json` 的 `@aqutter/aqutter` 以 `github:Aqutter/aqutter-js#<ref>` 安裝（開發依賴，peer 為可選）；對應框架版本見 `Aqutter/aqutter` 的 `manifest/releases.json`。
- **殼版本需與 App 相同**：`pubspec.yaml` 的 `aqutter` git ref 要與使用它的 App 一致。
- **開發階段版本統一為 `0.0.0`**。
- **多平台**：Android、iOS 用原生地圖（鏡像）、其他平台用 Google Maps JavaScript API；網頁只用 `googleMaps.mount()`，兩個 provider 的方法與事件必須一致。JS API key 由使用端 App 以 `googleMaps.configure({ jsApiKey })` 傳入，plugin 不讀檔案、不把 key 寫進 repo；原生 SDK 與 JS API 是不同的 key。
- **Dart 端宣告 `supportedPlatforms`**（Android、iOS）：其他平台殼不呼叫本 plugin 的 `attach`、`buildUnderlay` 與 handler。

## 驗證

```bash
pnpm install
pnpm typecheck
```
