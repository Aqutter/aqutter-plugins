import 'dart:ui' show Offset, Rect, Size;

/// 不鏡像模式：網頁上放地圖的容器（「洞」）與底層滿版地圖之間的換算。純邏輯、不碰平台，所以能單元測試。
///
/// 座標單位都是邏輯像素（CSS px），原點是螢幕左上角（WebView 滿版，與 Flutter 同一個座標系）。
class AqutterHoleLayout {
  const AqutterHoleLayout({required this.reference, required this.shift});

  /// 基準矩形：洞第一次回報（或大小改變）時的位置。相機目標對到它的中心（[centerOffset]）。
  final Rect reference;

  /// 底層地圖相對基準的平移量：洞隨頁面捲動時，地圖跟著洞走。
  final Offset shift;

  /// 底層地圖目前在螢幕上的矩形：大小等於洞，位置是基準位置加上平移量。地圖與洞同大，相機中心自然落在洞中心；
  /// 洞一開始有一部分在螢幕外也沒關係（捲進來時地圖已經涵蓋它）。
  Rect get mapRect => reference.shift(shift);

  /// 洞回報新矩形 [rect] 後的結果：大小沒變只更新平移；大小變了（或第一次）就以 [rect] 當新基準、平移歸零。
  static AqutterHoleLayout update(AqutterHoleLayout? previous, Rect rect) {
    if (previous == null || previous.reference.size != rect.size) {
      return AqutterHoleLayout(reference: rect, shift: Offset.zero);
    }
    return AqutterHoleLayout(reference: previous.reference, shift: rect.topLeft - previous.reference.topLeft);
  }
}

/// 網頁手勢（位置與位移是相對視窗大小的 0..1）換成相對於底層地圖本身的 0..1。
/// - `tap`、`doubleTap`、`pinch` 的位置 `x`、`y`：先換成螢幕座標，扣掉地圖目前的左上角，再除以地圖大小。
/// - `pan` 的位移 `dx`、`dy`：換成像素後除以地圖大小。
/// 其他欄位原樣保留。
Map<String, dynamic> toMapGesture(Map<String, dynamic> payload, {required Size viewport, required Rect mapRect}) {
  if (viewport.isEmpty || mapRect.isEmpty) {
    return payload;
  }
  final type = payload['type'];
  final x = payload['x'];
  final y = payload['y'];
  final dx = payload['dx'];
  final dy = payload['dy'];
  if ((type == 'tap' || type == 'doubleTap' || type == 'pinch') && x is num && y is num) {
    return {
      ...payload,
      'x': (x * viewport.width - mapRect.left) / mapRect.width,
      'y': (y * viewport.height - mapRect.top) / mapRect.height,
    };
  }
  if (type == 'pan' && dx is num && dy is num) {
    return {
      ...payload,
      'dx': dx * viewport.width / mapRect.width,
      'dy': dy * viewport.height / mapRect.height,
    };
  }
  return payload;
}
