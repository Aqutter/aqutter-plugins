# aqutter-plugin-google-maps

Aqutter plugin：把 `google_maps_flutter` 的地圖在 Flutter 裡渲染（墊在 WebView 之下），以 native view 鏡像顯示到網頁的 `<aqutter-native>` canvas。網頁因此能在地圖**之上**疊任何 HTML、做 z-index 與動畫；拖曳、縮放、點擊從網頁回傳，換成地圖的相機操作。

**多平台**：Android、iOS 用上述的原生地圖；其他平台（macOS、Windows、Linux，以及純瀏覽器）用 **Google Maps JavaScript API**。網頁只寫一份 `googleMaps.mount(container)`，兩者的方法與事件一致，也都能在地圖上疊 HTML。

| 平台 | 地圖由誰繪製 | 需要的 key |
|---|---|---|
| Android、iOS | 原生地圖（`google_maps_flutter`），鏡像到 `<aqutter-native>` | 原生 SDK key（見下方） |
| 其他 | Google Maps JavaScript API，直接在網頁裡繪製 | JS API key（見下方，與原生 key 是**不同**的 key） |

## 安裝

在 Aqutter 專案：

```bash
pnpm exec aqutter plugin add github:Aqutter/aqutter-plugin-google-maps
```

## 網頁端

```html
<div id="map" style="position: relative; height: 360px">
  <div class="overlay">任何 HTML 都可以疊在地圖上</div>
</div>
```

```ts
import { googleMaps } from 'aqutter-plugin-google-maps'

// 非原生平台用的 JS API key：由 App 傳入（例如來自自己的環境變數），不要寫進會提交的檔案
googleMaps.configure({ jsApiKey: useRuntimeConfig().public.googleMapsJsApiKey })

const map = await googleMaps.mount(document.getElementById('map')!, {
  camera: { lat: 35.6762, lng: 139.6503, zoom: 11 },
})
await map.setMarkers([{ id: 'tokyo', lat: 35.6762, lng: 139.6503, title: 'Tokyo' }])
map.onTap(({ lat, lng }) => console.log('tapped', lat, lng))
map.onCameraIdle(camera => console.log(camera))
// 不再使用時
map.destroy()
```

| 成員 | 說明 |
|---|---|
| `googleMaps.configure({ jsApiKey })` | 設定非原生平台用的 JS API key；須在 `mount` 前呼叫，原生平台忽略 |
| `googleMaps.provider()` | 同步：`'native'` 或 `'js'`。依殼回報的能力表判斷 |
| `googleMaps.mount(container, { camera?, mapType? })` | 在 `container` 內建立地圖，回傳 `GoogleMapsView`。`'js'` 沒有 `configure` 過 key、或腳本載入失敗／逾時（15 秒）都會 reject |
| `GoogleMapsView.provider` | 這張地圖用的 provider |
| `getCamera()` | 目前相機：`{ lat, lng, zoom }` |
| `moveTo(lat, lng, { zoom?, animate? })` | 移動相機；預設立即移動，`animate: true` 才做動畫（原生端的動畫要靠地圖持續繪圖） |
| `setMarkers(markers)` | 以這份清單取代全部標記 |
| `setMapType(type)` | `normal`／`satellite`／`terrain`／`hybrid` |
| `onReady` / `onCameraIdle` / `onTap` | 事件，回傳取消訂閱函式 |
| `destroy()` | 移除地圖與所有監聽 |

操作（原生）：單指拖曳平移、雙指縮放、雙擊放大、單擊回報經緯度。JS 地圖用 Google 預設的手勢。

> **在 App 的平台資訊就緒之後再 `mount`。** `provider()` 依殼回報的能力表判斷；能力表還沒取得時（啟動早期）一律視為支援，會回 `'native'`，在桌面平台會選錯。

> **頂層的 `isSupported()`、`moveTo()` 等已移除**（開發階段的破壞式變更），改由 `mount` 回傳的 `GoogleMapsView` 提供。

## 非原生平台：Google Maps JavaScript API

macOS、Windows、Linux 與純瀏覽器用 Google Maps JavaScript API 繪製地圖。

1. 在 [Google Cloud Console](https://console.cloud.google.com/google/maps-apis) 啟用 **Maps JavaScript API**（需要計費）並建立一組 **JS API key**。這和原生 SDK 的 key 是**分開**的 key。
2. 由使用端 App 在 `mount` 之前呼叫 `googleMaps.configure({ jsApiKey })`。plugin 不讀任何檔案，key 不要寫進會提交的檔案。
3. 網頁的 Content-Security-Policy 要放行 Google 的腳本、圖磚、樣式與字型來源。**確切網域尚未實測**（沒有 key 無法載入真的地圖），請以瀏覽器 console 的 CSP 違規訊息為準逐一放行。
4. **key 的網址限制尚未驗證**：release 版網頁由殼的本機 server 供應，來源是 `http://127.0.0.1:<隨機埠>`，隨機埠讓 HTTP referrer 限制不好寫；怎麼填請以實測為準，驗證後會補在這裡。

> 這一段在撰寫時只用假的 `google.maps` 物件做過單元測試，**還沒有用真的 key 載入過 Google 的腳本**。

## 設定 Google Maps API key（原生，Android、iOS）

沒有 key 時，Android 會顯示灰色空白地圖，iOS 會在建立地圖時出錯。key 由使用端 App 設定，**不要**把 key 寫進會提交的檔案。

1. 在 [Google Cloud Console](https://console.cloud.google.com/google/maps-apis) 建立專案並啟用計費，啟用 **Maps SDK for Android** 與 **Maps SDK for iOS**，各建立一組 API key（建議分開，方便分別限制）。
2. 限制 key：Android key 限制「Android 應用程式」並填套件名稱與簽章指紋（SHA-1）；iOS key 限制「iOS 應用程式」並填 bundle ID。

### Android

`android/local.properties`（已被 git 忽略，不會提交）加一行：

```properties
GOOGLE_MAPS_API_KEY=你的 Android key
```

`android/app/build.gradle.kts` 最上面加 `import java.util.Properties`，並在 `defaultConfig` 區塊加上：

```kotlin
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
manifestPlaceholders["googleMapsApiKey"] = localProperties.getProperty("GOOGLE_MAPS_API_KEY", "NO_KEY")
```

`android/app/src/main/AndroidManifest.xml` 的 `<application>` 裡加上：

```xml
<meta-data android:name="com.google.android.geo.API_KEY" android:value="${googleMapsApiKey}" />
```

### iOS

建立 `ios/Flutter/Secrets.xcconfig`（加進 `.gitignore`）：

```
GOOGLE_MAPS_API_KEY = 你的 iOS key
```

在 `ios/Flutter/Debug.xcconfig` 與 `ios/Flutter/Release.xcconfig` 各加一行：

```
#include? "Secrets.xcconfig"
```

`ios/Runner/Info.plist` 加上：

```xml
<key>GMSApiKey</key>
<string>$(GOOGLE_MAPS_API_KEY)</string>
```

`ios/Runner/AppDelegate.swift`：

```swift
import GoogleMaps
// …
override func application(
  _ application: UIApplication,
  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
  // 沒有設定 key 時用佔位值：地圖顯示灰色（授權失敗）但不會崩潰。
  // iOS 若完全沒呼叫 provideAPIKey，建立地圖時 App 會直接終止。
  let key = (Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String) ?? ""
  GMSServices.provideAPIKey(key.isEmpty ? "NO_KEY" : key)
  return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}
```

`ios/Flutter/Secrets.xcconfig` 記得加進 `.gitignore`：

```
ios/Flutter/Secrets.xcconfig
```

## 運作方式與限制

- 擷取：Flutter 的 `RepaintBoundary.toImage` 抓不到地圖（鏡像會是透明的）。Android 直接擷取地圖內的 `TextureView`；iOS 用原生 `drawHierarchy` 擷取地圖 view。Android 地圖用 texture 模式（`useAndroidViewSurface = false`），本 plugin 會自動設定。
- 效能（Android 平板實測，滿版約 3200 像素寬）：約 15 fps，每幀約 10 MB。
- 輸入走網頁判斷的語意手勢（`input="gestures"`，預設），換成相機更新。iOS 的 PlatformView 不接受注入的 Flutter 指標事件，所以不用 `input="pointers"`。
- 擷取成本取決於地圖像素數；移動中的解析度預設是 `smooth`（固定在框架預設 `AqutterNative.defaultMinScale`（0.4），`GoogleMapsPlugin(quality:, minScale:)` 可調），停下來補完整解析度的定格幀。效能細節見 [aqutter_core 的 doc/nativeview.md](https://github.com/Aqutter/aqutter_core/blob/main/doc/nativeview.md)。
