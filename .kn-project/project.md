<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# aqutter-plugins

Aqutter 官方 plugin 的 monorepo（pnpm workspace，`packages/<dir>/`）。每個 plugin 同時是 npm 套件與 Dart 套件，由 `aqutter plugin add "github:Aqutter/aqutter-plugins#path:/packages/<dir>"` 安裝到使用 Aqutter 的 App。詳見 [README.md](../README.md)。

## 保留鐵則

- **治理單位是這個 repo**：計畫與歸檔都放在根目錄的 `.kn-project/`，各 package 底下不再放 `.kn-project`。
- **client 依賴來自 `Aqutter/aqutter-js`**：各 package 的 `@aqutter/aqutter` 以 `github:Aqutter/aqutter-js#<ref>` 安裝（開發依賴，peer 為可選）；對應框架版本見 `Aqutter/aqutter` 的 `manifest/releases.json`。
- **殼版本需與 App 相同**：各 package 的 `pubspec.yaml` 的 `aqutter` git ref 要與使用它的 App 一致。
- **plugin id、npm 套件名、Dart 套件名一律不改**：既有 App 的 `aqutter.config.json` 與 `plugin sync` 依賴它們。
- **開發階段版本統一為 `0.0.0`**。

## 驗證

```bash
pnpm install
pnpm verify
```
