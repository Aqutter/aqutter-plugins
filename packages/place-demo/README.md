# aqutter-plugin-place-demo

三層呼叫鏈的**頂層**示範：網頁 → `place-demo` → `nearby-demo`（internal）→ `location`。網頁只認識 `place-demo`，底下兩層由 Dart 端經 `context.callPlugin` 逐層轉呼叫。

## 相依

| 項目 | 說明 |
|---|---|
| `requires` | `aqutter-plugin-nearby-demo` `^0.0.0`；它自己又 `requires` `aqutter-plugin-location`。`aqutter plugin add` 兩層都會連帶安裝並登記 |
| 方法 | `whereAmI`：`{ layers, ready, permission, position \| null }` |

## 安裝

```bash
aqutter plugin add "github:Aqutter/aqutter-plugins#path:/packages/place-demo"
```

pnpm 11 預設禁止 plugin 的間接依賴來自 GitHub，開發階段要在專案的 `pnpm-workspace.yaml` 設 `blockExoticSubdeps: false`；plugin 發佈到 npm 之後不需要。要定位成功，App 還要宣告定位權限（見 `aqutter-plugin-location`）。

## 使用

```ts
import { placeDemo } from 'aqutter-plugin-place-demo'

const result = await placeDemo.whereAmI()
// { layers: ['place-demo', 'nearby-demo', 'location'], ready: true, permission: 'granted', position: {...} }
```

網頁直接呼叫 `nearby-demo` 會得到 `undefined`（`isPluginSupported('nearby-demo', 'snapshot')` 為 `false`），因為它是 internal。

## 開發

```bash
pnpm install
pnpm typecheck
flutter pub get
flutter test
```
