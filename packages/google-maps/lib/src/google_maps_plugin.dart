import 'dart:async';

import 'package:aqutter/aqutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'gesture_mapper.dart';

/// 以 `--dart-define=AQUTTER_MAP_BASELINE=true` 關掉主執行緒占用上限（預設 0.7），效能 A/B 比較用。
const bool _baseline = bool.fromEnvironment('AQUTTER_MAP_BASELINE');

/// 以 `--dart-define=AQUTTER_MAP_DUTY=0.7` 指定原生擷取佔用主執行緒的上限（0 到 1），效能量測用；沒給時用 `AqutterNative` 的預設（0.7）。
/// 以 `--dart-define=AQUTTER_MAP_MINSCALE=0.25` 覆蓋解析度下限（量測用）。
final double? _minScaleOverride = double.tryParse(const String.fromEnvironment('AQUTTER_MAP_MINSCALE'));

final double? _dutyOverride = double.tryParse(const String.fromEnvironment('AQUTTER_MAP_DUTY'));

/// 網頁 `<aqutter-native session="google-maps">` 對應的工作階段 id。
const String aqutterGoogleMapsSession = 'google-maps';

/// Google 地圖 plugin：地圖在 Flutter 裡渲染（墊在 WebView 之下），以 [AqutterNative] 鏡像到網頁的 canvas，
/// 網頁因此能在地圖**之上**疊 HTML。手勢從網頁回傳，經 [AqutterMapGestureMapper] 換成相機更新。
///
/// 平台：原生地圖只有 Android、iOS（[nativePlatforms]）。[supportedPlatforms] 宣告了這件事，所以其他平台上
/// 殼不會呼叫本 plugin 的 `attach`、`buildUnderlay` 與 handler；網頁端的 `googleMaps.mount()` 在那些平台改用
/// Google Maps JavaScript API（見 README），不需要 Dart 端參與。
///
/// 使用前須設定 Google Maps API key，見 README。
class GoogleMapsPlugin extends AqutterPlugin {
  GoogleMapsPlugin({
    this.pluginId = aqutterGoogleMapsSession,
    this.alignment = Alignment.center,
    this.widthFactor = 1.0,
    this.heightFactor = 1.0,
    this.initialCamera = const CameraPosition(target: LatLng(25.0330, 121.5654), zoom: 12),
    this.quality,
    this.maxFps,
    this.minScale,
    this.mapType = MapType.normal,
  });

  /// 外掛 id，也是網頁 `<aqutter-native session="…">` 的 session。同一頁要放多個地圖時，各給一個不同的 id
  /// （預設 `google-maps`）；網頁以 `callPlugin(id, …)` 呼叫各自的方法。
  final String pluginId;

  /// 這個地圖在 App 畫面上占的位置與比例（相對於整個畫面）；預設滿版。兩個地圖左右各一半時，
  /// 一個設 `Alignment.centerLeft`、一個設 `Alignment.centerRight`，`widthFactor` 都是 0.5。
  /// 網頁上對應的 `<aqutter-native>` 元素要放在同樣的左右半邊，擷取的解析度才與顯示的大小一致。
  final Alignment alignment;
  final double widthFactor;
  final double heightFactor;

  /// 地圖載入時的相機位置（預設台北）。
  final CameraPosition initialCamera;

  /// 移動中的解析度政策；`null`（預設）是 `smooth`（固定在 [minScale]，停下來補完整解析度）。
  final AqutterNativeQuality? quality;

  /// 選填的擷取頻率硬上限；`null`（預設）不限制。地圖的擷取要 40 ms 以上，這個上限從來不會綁住它。
  final int? maxFps;

  /// 移動中的解析度倍率（線性，相對於網頁元素的基準解析度）；`null`（預設）沿用框架預設 `AqutterNative.defaultMinScale`（0.4）。停下來會補一張完整解析度的定格幀。
  final double? minScale;

  final MapType mapType;

  AqutterPluginContext? _context;
  /// 最近一次 `onMapCreated` 給的控制器。`GoogleMap` widget 被銷毀再重建時會得到新的控制器，舊的一旦銷毀就不能再用
  /// （會丟「was used after the associated GoogleMap widget had already been disposed」），所以每次建立都要換成最新的。
  GoogleMapController? _mapController;
  final AqutterMapGestureMapper _mapper = AqutterMapGestureMapper();
  final ValueNotifier<Set<Marker>> _markers = ValueNotifier<Set<Marker>>(<Marker>{});
  final ValueNotifier<MapType> _type = ValueNotifier<MapType>(MapType.normal);
  CameraPosition _camera = const CameraPosition(target: LatLng(0, 0));
  AqutterMapSize _size = (width: 0, height: 0);

  /// 有 google_maps_flutter 原生實作的平台：Android 與 iOS。
  static const Set<TargetPlatform> nativePlatforms = {TargetPlatform.android, TargetPlatform.iOS};

  @override
  Set<TargetPlatform>? get supportedPlatforms => nativePlatforms;

  @override
  String get id => pluginId;

  @override
  Map<String, AqutterPluginHandler> get handlers => {
        'getCamera': (payload) async => _cameraJson(),
        // 除錯：原生擷取與連線的內部狀態（地圖卡住時看是哪一段停了）
        'diag': (payload) async => {
              ...AqutterNativeHost.instance.diagnostics(pluginId),
              'controllerReady': _mapController != null,
              'applying': _applying,
              'pending': _pending.hasPending,
              'camera': _cameraJson(),
            },
        'moveTo': (payload) async {
          final controller = await _readyController();
          if (controller == null) {
            return {'ok': false};
          }
          final target = _latLng(payload);
          if (target == null) {
            return {'ok': false};
          }
          final zoom = payload['zoom'];
          final update = zoom is num ? CameraUpdate.newLatLngZoom(target, zoom.toDouble()) : CameraUpdate.newLatLng(target);
          // 預設立即移動：動畫要靠地圖持續繪圖，沒有 key（或地圖沒在繪圖）時動畫不會跑，所以只在明確要求時才用
          if (payload['animate'] == true) {
            await controller.animateCamera(update);
          }
          else {
            await controller.moveCamera(update);
          }
          // 相機回呼（onCameraMove）在地圖沒繪圖時不會來，這裡先記下目標，getCamera 才不會讀到舊值
          _camera = CameraPosition(target: target, zoom: zoom is num ? zoom.toDouble() : _camera.zoom);
          return {'ok': true};
        },
        'setMarkers': (payload) async {
          final list = payload['markers'];
          _markers.value = {
            if (list is List)
              for (final entry in list)
                if (entry is Map && _latLng(entry.cast<String, dynamic>()) != null)
                  Marker(
                    markerId: MarkerId('${entry['id'] ?? entry.hashCode}'),
                    position: _latLng(entry.cast<String, dynamic>())!,
                    infoWindow: InfoWindow(title: entry['title'] as String?),
                  ),
          };
          return {'count': _markers.value.length};
        },
        'setMapType': (payload) async {
          _type.value = switch (payload['type']) {
            'satellite' => MapType.satellite,
            'terrain' => MapType.terrain,
            'hybrid' => MapType.hybrid,
            _ => MapType.normal,
          };
          return {'type': _type.value.name};
        },
      };

  @override
  void attach(AqutterPluginContext context) {
    _context = context;
    _type.value = mapType;
    _camera = initialCamera;
    final platform = GoogleMapsFlutterPlatform.instance;
    if (platform is GoogleMapsFlutterAndroid) {
      // texture 模式：地圖以 Texture 進 Flutter 的合成，RepaintBoundary 才擷取得到；
      // Hybrid Composition（AndroidViewSurface）的內容不在 Flutter 的圖層裡，擷取不到。
      platform.useAndroidViewSurface = false;
    }
  }

  @override
  Widget? buildUnderlay(BuildContext context) {
    if (kIsWeb || !nativePlatforms.contains(defaultTargetPlatform)) {
      return null;
    }
    return Positioned.fill(
      child: FractionallySizedBox(
        alignment: alignment,
        widthFactor: widthFactor,
        heightFactor: heightFactor,
        child: AqutterNative(
        sessionId: pluginId,
        quality: quality,
        maxFps: maxFps,
        minScale: _minScaleOverride ?? minScale,
        nativeMaxDuty: _baseline ? 1.0 : _dutyOverride,
        matchViewportAspect: true,
        // RepaintBoundary.toImage 擷取不到地圖（texture／PlatformView 的內容，鏡像會是透明的），改用原生擷取：
        // Android 用 PixelCopy 複製 Flutter 的繪圖表面，iOS 用 drawHierarchy 直接擷取地圖 view
        nativeCapture: true,
        nativeViewTypeContains: 'GMSMapView',
        onMessage: _onMessage,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _size = (width: constraints.maxWidth, height: constraints.maxHeight);
            return ValueListenableBuilder<Set<Marker>>(
              valueListenable: _markers,
              builder: (context, markers, _) => ValueListenableBuilder<MapType>(
                valueListenable: _type,
                builder: (context, type, _) => GoogleMap(
                  initialCameraPosition: initialCamera,
                  mapType: type,
                  markers: markers,
                  // 地圖被網頁蓋住，系統的控制項沒有意義；操作由網頁決定
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _context?.emit('ready', {'camera': _cameraJson()});
                  },
                  // 注意：iOS 上程式化移動相機（moveCamera）不會觸發這個回呼，所以不能拿它當縮放的基準
                  onCameraMove: (position) => _camera = position,
                  onCameraIdle: () => _context?.emit('cameraIdle', _cameraJson()),
                ),
              ),
            );
          },
        ),
        ),
      ),
    );
  }

  Future<GoogleMapController?> _readyController() async => _mapController;

  Future<void> _onMessage(AqutterNativeMessage message) async {
    final controller = await _readyController();
    if (controller == null) {
      return;
    }
    if (message.type == 'tap') {
      await _emitTap(controller, message);
      return;
    }
    // 變動先累加，再由 _applyPending 一次套用最新的合併結果（原生地圖忙時不堆積，理由見 AqutterMapCameraAccumulator）
    _pending.add(_mapper.update(message, size: _size));
    await _applyPending(controller);
  }

  final AqutterMapCameraAccumulator _pending = AqutterMapCameraAccumulator();
  bool _applying = false;

  /// 套用累積的相機變動。同一時間只有一個在跑；跑的當中新來的變動累加在 [_pending]，這一輪結束後接著套用。
  /// 一律立即套用、不做動畫（理由見 moveTo）。
  Future<void> _applyPending(GoogleMapController controller) async {
    if (_applying) {
      return;
    }
    _applying = true;
    try {
      while (_pending.hasPending) {
        for (final update in _pending.take().toUpdates()) {
          await controller.moveCamera(update);
        }
      }
    }
    finally {
      _applying = false;
    }
  }

  /// 點擊：換成經緯度回報給網頁（座標為地圖元件的實體像素）。
  Future<void> _emitTap(GoogleMapController controller, AqutterNativeMessage message) async {
    final x = message.number('x');
    final y = message.number('y');
    if (x == null || y == null) {
      return;
    }
    final ratio = PlatformDispatcher.instance.views.first.devicePixelRatio;
    final point = await controller.getLatLng(ScreenCoordinate(x: (x * _size.width * ratio).round(), y: (y * _size.height * ratio).round()));
    unawaited(_context?.emit('tap', {'lat': point.latitude, 'lng': point.longitude}));
  }

  Map<String, Object> _cameraJson() => {
        'lat': _camera.target.latitude,
        'lng': _camera.target.longitude,
        'zoom': _camera.zoom,
      };

  LatLng? _latLng(Map<String, dynamic> payload) {
    final lat = payload['lat'];
    final lng = payload['lng'];
    return lat is num && lng is num ? LatLng(lat.toDouble(), lng.toDouble()) : null;
  }

  @override
  void dispose() {
    _context = null;
    _mapController = null;
    _markers.dispose();
    _type.dispose();
  }
}
