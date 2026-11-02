# aqutter-plugins

Aqutter 官方 plugin 的 monorepo。每個 plugin 同時是 npm 套件（網頁端 API）與 Dart 套件（Flutter 端），位於 `packages/<dir>/`。

| plugin | 資料夾 | id | 說明 |
|---|---|---|---|
| battery | `packages/battery` | `battery` | 電量與充電狀態 |
| biometrics | `packages/biometrics` | `biometrics` | 叫起系統的驗證視窗（生物辨識或裝置密碼），任何時候都能呼叫 |
| file-manager | `packages/file-manager` | `file-manager` | App 資料夾、使用者授權的位置、相簿與下載的檔案管理 |
| google-maps | `packages/google-maps` | `google-maps` | 地圖鏡像到網頁，可在地圖上疊 HTML |
| haptics | `packages/haptics` | `haptics` | 觸覺回饋 |
| mirror-demo | `packages/mirror-demo` | `mirror-demo` | 原生 view 鏡像的示範 |
| secure-storage | `packages/secure-storage` | `secure-storage` | 安全儲存，可要求生物辨識或裝置密碼才能讀出 |
| sqlite-drift | `packages/sqlite-drift` | `sqlite` | SQLite（drift），網頁端是 Kysely dialect |

## 安裝到 App

```bash
# 從 GitHub 只裝單一 plugin（pnpm 的 #path: 只會安裝那個子資料夾）
aqutter plugin add "github:Aqutter/aqutter-plugins#path:/packages/haptics"

# 發佈到 npm 之後
aqutter plugin add aqutter-plugin-haptics
```

`aqutter plugin add` 會登記 plugin、補上 `pubspec.yaml` 的依賴與註冊清單，並印出該 plugin 還需要你在原生專案補的設定（見各 plugin 的 README）。

## 開發

```bash
pnpm install        # 安裝所有 package 的網頁端依賴
pnpm typecheck      # 全部 package 的 tsc
pnpm test           # 有 vitest 的 package
pnpm test:dart      # 逐個 package 的 flutter pub get 與 flutter test；只跑一個：pnpm test:dart haptics
pnpm verify         # 以上全部
```

新增一個官方 plugin：在 `packages/` 底下用 `aqutter plugin create <id> --dir=packages/aqutter-plugin-<id>` 產生後，把資料夾改名成 `<id>`（不含 `aqutter-plugin-` 前綴）。

## 規則

- plugin id、npm 套件名（`aqutter-plugin-<dir>`）與 Dart 套件名不因為搬進這個 repo 而改變。
- 每個 package 的殼版本（`pubspec.yaml` 的 `aqutter` git ref）要與使用它的 App 一致。
- 開發階段版本統一為 `0.0.0`。
- **plugin 用不了的平台不拋錯**：網頁端 `callPlugin` 回 `undefined`（開發階段才在 console 警告），各 plugin 的網頁 API 回安全的預設值（列表回 `[]`、讀取回 `null`、寫入不做事），並在自己的 README 說明；想事先判斷用 `isPluginSupported`。唯一的例外是 `sqlite-drift`：資料庫用不了時明確拋錯，因為回空結果會默默丟掉寫入。
- 第三方或自己寫的 plugin 不需要放進這個 repo；`aqutter plugin create` 產生的範本可以獨立成一個 repo。

治理文件在 `.kn-project/`（計畫與歸檔）；從各舊 repo 搬來的歸檔在 `.kn-project/archive/legacy-plugin-repos/`。
