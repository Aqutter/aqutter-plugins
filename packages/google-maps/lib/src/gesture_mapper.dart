import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:aqutter/aqutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 一次相機變動：縮放增量（zoom level）、縮放焦點（地圖元件的邏輯像素），以及平移量（`scrollBy` 的參數，已是相機方向）。
class AqutterMapDelta {
  const AqutterMapDelta({this.zoom = 0, this.focal, this.scroll = Offset.zero});

  static const AqutterMapDelta none = AqutterMapDelta();

  final double zoom;
  final Offset? focal;
  final Offset scroll;

  bool get isEmpty => zoom.abs() < 1e-9 && scroll.distance < 1e-9;

  /// 轉成要依序套用的相機更新：先縮放（帶焦點）、再平移。
  List<CameraUpdate> toUpdates() => [
        if (zoom.abs() >= 1e-9) (focal != null ? CameraUpdate.zoomBy(zoom, focal!) : CameraUpdate.zoomBy(zoom)),
        if (scroll.distance >= 1e-9) CameraUpdate.scrollBy(scroll.dx, scroll.dy),
      ];
}

/// 合併相機變動：原生地圖忙的時候，後來的變動累加起來，忙完只套用最新的合併結果。
///
/// 雙指按住不放時，每個觸控移動事件都會產生一筆變動（iPad 一秒上百筆），若逐筆送給原生地圖，
/// 更新會越排越多、地圖停住。縮放與平移都是增量，所以累加後一次套用與逐筆套用的結果相同（焦點取最新的）。
class AqutterMapCameraAccumulator {
  double _zoom = 0;
  Offset? _focal;
  Offset _scroll = Offset.zero;

  bool get hasPending => _zoom.abs() >= 1e-9 || _scroll.distance >= 1e-9;

  void add(AqutterMapDelta delta) {
    _zoom += delta.zoom;
    _focal = delta.focal ?? _focal;
    _scroll += delta.scroll;
  }

  /// 取走目前累積的變動並清空。
  AqutterMapDelta take() {
    final delta = AqutterMapDelta(zoom: _zoom, focal: _focal, scroll: _scroll);
    _zoom = 0;
    _focal = null;
    _scroll = Offset.zero;
    return delta;
  }
}

/// 把網頁傳來的語意手勢（`pan` / `pinch` / `doubleTap`）換成地圖的相機更新。
///
/// 純邏輯、不碰平台，所以能單元測試。座標單位：地圖的 `scrollBy` 與 `zoomBy` 的焦點都以地圖元件的邏輯像素為單位，
/// 網頁的位移與位置是相對元素大小的 0..1 正規化值，因此要乘上地圖目前的大小。
///
/// 縮放用**增量**（`zoomBy`）並帶焦點，不用絕對值（`zoomTo`）：
/// - `zoomTo` 永遠繞著地圖中心縮放，兩指中心的地理位置會跑掉（「在錯的點展開」）；
/// - 絕對值需要知道目前的縮放，那個值來自相機回呼、是非同步更新的，一旦不同步，下一次縮放就以錯的基準計算。
class AqutterMapGestureMapper {
  double _lastScale = 1;
  Offset? _lastFocal;

  /// 回傳該訊息對應的相機變動；不影響相機的訊息（`tap`、`longPress`…）回 [AqutterMapDelta.none]。
  AqutterMapDelta update(AqutterNativeMessage message, {required AqutterMapSize size}) {
    switch (message.type) {
      case 'pan':
        if (message.data['phase'] != 'update') {
          return AqutterMapDelta.none;
        }
        final dx = (message.number('dx') ?? 0) * size.width;
        final dy = (message.number('dy') ?? 0) * size.height;
        // 手指往右拖，地圖內容跟著往右，相機目標反而往左
        return AqutterMapDelta(scroll: Offset(-dx, -dy));
      case 'pinch':
        return _pinch(message, size);
      case 'doubleTap':
        // 以點到的位置為焦點放大一級（沒有位置就繞中心）
        final x = message.number('x');
        final y = message.number('y');
        return AqutterMapDelta(zoom: 1, focal: x != null && y != null ? Offset(x * size.width, y * size.height) : null);
      default:
        return AqutterMapDelta.none;
    }
  }

  AqutterMapDelta _pinch(AqutterNativeMessage message, AqutterMapSize size) {
    final phase = message.data['phase'];
    final x = message.number('x');
    final y = message.number('y');
    final focal = x != null && y != null ? Offset(x * size.width, y * size.height) : null;
    if (phase == 'start') {
      _lastScale = 1;
      _lastFocal = focal;
      return AqutterMapDelta.none;
    }
    if (phase != 'update') {
      _lastFocal = null;
      return AqutterMapDelta.none;
    }
    final scale = message.number('scale') ?? 1;
    if (scale <= 0) {
      return AqutterMapDelta.none;
    }
    // 網頁送的是自 pinch 開始的累計倍率；換成這一次相對上一次的增量（兩指距離加倍＝放大一級）
    final amount = math.log(scale / _lastScale) / math.ln2;
    _lastScale = scale;
    final previousFocal = _lastFocal;
    _lastFocal = focal;
    // 兩指中心移動＝平移（與單指拖曳同向）
    final move = previousFocal != null && focal != null ? focal - previousFocal : Offset.zero;
    return AqutterMapDelta(zoom: amount.abs() > 1e-6 ? amount : 0, focal: focal, scroll: Offset(-move.dx, -move.dy));
  }
}

/// 地圖元件的大小（邏輯像素）；用具名記錄而不是 Flutter 的 `Size`，測試不必依賴 UI 型別。
typedef AqutterMapSize = ({double width, double height});
