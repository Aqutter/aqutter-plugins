<!-- REMINDER: Relative Paths Only! No file:///c:/... -->
# aqutter-plugin-haptics

Aqutter plugin（Dart 套件 + TypeScript 封裝），由 `aqutter plugin add github:Aqutter/aqutter-plugin-haptics` 安裝到使用 Aqutter 的 App。詳見 [README.md](../README.md)。

## 保留鐵則

- **client 依賴來自 `Aqutter/aqutter-js`**：`package.json` 的 `@aqutter/aqutter` 以 `github:Aqutter/aqutter-js#<ref>` 安裝（開發依賴，peer 為可選）；對應框架版本見 `Aqutter/aqutter` 的 `manifest/releases.json`。
- **殼版本需與 App 相同**：`pubspec.yaml` 的 `aqutter` git ref 要與使用它的 App 一致。
- **開發階段版本統一為 `0.0.0`**。

## 驗證

```bash
pnpm install
pnpm typecheck
```
