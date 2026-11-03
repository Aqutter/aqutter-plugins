# aqutter-plugin-nearby-demo

示範用的**內部**中間層 plugin：Dart 端經 `context.callPlugin('location', …)` 取得定位狀態與目前位置，整理成一份快照。

它覆寫 `internal => true`，殼**不**對網頁註冊它的方法，網頁直接呼叫得到 `HANDLER_NOT_FOUND`（`callPlugin` 回 `undefined`）。只有別的 plugin 能呼叫它，例如 [aqutter-plugin-place-demo](../place-demo)。

## 相依

| 項目 | 說明 |
|---|---|
| `requires` | `aqutter-plugin-location` `^0.0.0`；`aqutter plugin add` 會連帶安裝並登記 |
| 方法 | `snapshot`：`{ serviceEnabled, permission, position \| null }`；沒有定位權限、服務關閉或逾時時 `position` 為 `null`，不拋錯 |

## 安裝

通常不需要單獨安裝；安裝 `aqutter-plugin-place-demo` 時會連帶安裝。pnpm 11 預設禁止 plugin 的間接依賴來自 GitHub，開發階段要在專案的 `pnpm-workspace.yaml` 設 `blockExoticSubdeps: false`。

## 開發

```bash
pnpm install
pnpm typecheck
flutter pub get
flutter test
```
