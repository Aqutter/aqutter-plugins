import 'dart:math' as math;

import 'package:aqutter/aqutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';

/// native view 鏡像範例：一個純 Flutter 的互動畫面（圓、計數、色票），墊在 WebView 之下，
/// 以 `AqutterNative` 鏡像到網頁的 `<aqutter-native session="mirror-demo">`。
///
/// 輸入有兩種接法（網頁 `<aqutter-native input="…">`）：
///   - `gestures`（預設）：網頁判斷好 tap／pan／pinch 再傳來，由 [MirrorDemoState.apply] 套用。
///   - `pointers`：網頁只轉送原始指標事件，由畫面上的 `GestureDetector` 判斷（連點、長按、縮放都是 Flutter 的標準行為）。
///
/// 網頁端的手勢回到這裡改變畫面：
///   - `pan`：拖動圓　`pinch`：縮放圓　`tap`：計數 +1　`doubleTap`：歸零
///   - `longPress`：換色　`command` `reset`：回到初始狀態
///
/// 鏡像的對象換成 `google_maps_flutter` 的 `GoogleMap` 也是同一套寫法，見 README。
class MirrorDemoPlugin extends AqutterPlugin {
  MirrorDemoPlugin({this.quality, this.maxFps});

  /// 移動中的解析度政策；`null`（預設）是 `auto`（Flutter 自己畫的內容擷取很快，夠快就維持完整解析度）。
  final AqutterNativeQuality? quality;

  /// 選填的擷取頻率硬上限；`null`（預設）不限制。
  final int? maxFps;

  final MirrorDemoState state = MirrorDemoState();

  @override
  String get id => 'mirror-demo';

  @override
  Map<String, AqutterPluginHandler> get handlers => {
        // 網頁也能用一般 plugin 方法讀目前狀態（鏡像是另一條通道，互不影響）
        'state': (payload) async => state.toJson(),
        // 除錯：連線與已送出的幀數（`seq`）
        'diag': (payload) async => AqutterNativeHost.instance.diagnostics('mirror-demo'),
        // 壓力測試：整個畫面每一幀都在變（像全螢幕影片），看鏡像管線在最壞情況下的表現
        'animate': (payload) async {
          state.setAnimating(payload['on'] == true);
          return {'animating': state.animating};
        },
      };

  @override
  void attach(AqutterPluginContext context) {
    state.onCountChanged = (count) => context.emit('count', {'count': count});
  }

  @override
  Widget? buildUnderlay(BuildContext context) {
    return Positioned.fill(
      child: AqutterNative(
        sessionId: 'mirror-demo',
        quality: quality,
        maxFps: maxFps,
        matchViewportAspect: true,
        injectPointers: true, // 網頁 input="pointers" 時，由下面的 GestureDetector 自己判斷手勢
        onMessage: state.apply,
        child: MirrorDemoCanvas(state: state),
      ),
    );
  }

  @override
  void dispose() {
    state.dispose();
  }
}

/// 畫面狀態；網頁手勢經 [apply] 改它，[_DemoCanvas] 監聽並重繪。
class MirrorDemoState extends ChangeNotifier {
  static const List<Color> palette = [Color(0xFF3F51B5), Color(0xFFE91E63), Color(0xFF009688), Color(0xFFFF9800)];

  /// 圓心位置與大小，皆為 0..1 的正規化值（相對畫面）。
  Offset center = const Offset(0.5, 0.5);
  double radius = 0.18;

  /// 旋轉角（弧度）；只有兩指旋轉（Flutter 標準手勢）會改變，語意手勢模式沒有旋轉。
  double rotation = 0;
  int count = 0;
  int colorIndex = 0;

  double _radiusAtPinchStart = 0.18;
  double _rotationAtScaleStart = 0;

  void Function(int count)? onCountChanged;

  /// 全螢幕動畫模式（像影片：每一幀整個畫面都在變），壓力測試用。
  bool animating = false;

  /// 動畫模式下目前的時間（秒）。
  double timeSeconds = 0;

  void setAnimating(bool on) {
    if (animating == on) {
      return;
    }
    animating = on;
    if (on) {
      SchedulerBinding.instance.scheduleFrameCallback(_animationFrame);
    }
    notifyListeners();
  }

  void _animationFrame(Duration timeStamp) {
    if (!animating) {
      return;
    }
    timeSeconds = timeStamp.inMicroseconds / Duration.microsecondsPerSecond;
    notifyListeners();
    SchedulerBinding.instance.scheduleFrameCallback(_animationFrame);
  }

  Color get color => palette[colorIndex % palette.length];

  /// 以正規化位移移動圓心（拖曳、慣性滑動用）。
  void moveBy(Offset delta) {
    center = Offset((center.dx + delta.dx).clamp(0.0, 1.0), (center.dy + delta.dy).clamp(0.0, 1.0));
    notifyListeners();
  }

  /// 開始一次縮放／旋轉手勢：記下目前的大小與角度，之後的倍率與旋轉量都相對於它。
  void beginScale() {
    _radiusAtPinchStart = radius;
    _rotationAtScaleStart = rotation;
  }

  /// 套用相對於 [beginScale] 的累計倍率與旋轉量（弧度）。
  void scaleTo(double scale, double rotationDelta) {
    radius = (_radiusAtPinchStart * scale).clamp(0.05, 0.45);
    rotation = _rotationAtScaleStart + rotationDelta;
    notifyListeners();
  }

  void apply(AqutterNativeMessage message) {
    switch (message.type) {
      case 'pan':
        if (message.data['phase'] == 'update') {
          center = Offset(
            (center.dx + (message.number('dx') ?? 0)).clamp(0.0, 1.0),
            (center.dy + (message.number('dy') ?? 0)).clamp(0.0, 1.0),
          );
        }
      case 'pinch':
        final phase = message.data['phase'];
        if (phase == 'start') {
          _radiusAtPinchStart = radius;
        }
        else if (phase == 'update') {
          radius = (_radiusAtPinchStart * (message.number('scale') ?? 1)).clamp(0.05, 0.45);
        }
      case 'tap':
        count += 1;
        onCountChanged?.call(count);
      case 'doubleTap':
        count = 0;
        onCountChanged?.call(count);
      case 'longPress':
        colorIndex += 1;
      case 'command':
        if (message.data['name'] == 'reset') {
          center = const Offset(0.5, 0.5);
          radius = 0.18;
          rotation = 0;
          count = 0;
          colorIndex = 0;
          onCountChanged?.call(count);
        }
      default:
        return;
    }
    notifyListeners();
  }

  Map<String, Object> toJson() => {
        'x': center.dx,
        'y': center.dy,
        'radius': radius,
        'count': count,
      };
}

/// 畫布。網頁 `input="gestures"` 時網頁判斷手勢、經 [MirrorDemoState.apply] 套用；
/// 網頁 `input="pointers"` 時，原始指標事件被注入這個 widget，由下面標準的 Flutter 手勢處理：
/// 單擊、雙擊（與單擊互斥）、長按、右鍵，以及單指拖曳、雙指縮放與旋轉（含多指）、放開後的慣性滑動。
class MirrorDemoCanvas extends StatefulWidget {
  const MirrorDemoCanvas({super.key, required this.state});

  final MirrorDemoState state;

  @override
  State<MirrorDemoCanvas> createState() => _MirrorDemoCanvasState();
}

class _MirrorDemoCanvasState extends State<MirrorDemoCanvas> with SingleTickerProviderStateMixin {
  MirrorDemoState get state => widget.state;

  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;

  /// 慣性滑動的速度（每秒的正規化位移），每個 tick 以摩擦力衰減。
  Offset _velocity = Offset.zero;
  Size _size = Size.zero;

  static AqutterNativeMessage _message(String type) => AqutterNativeMessage(type, const {});

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _stopFling() {
    _velocity = Offset.zero;
    if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    if (dt <= 0) {
      return;
    }
    state.moveBy(_velocity * dt);
    _velocity *= math.exp(-4 * dt);
    if (_velocity.distance < 0.02) {
      _ticker.stop();
    }
  }

  void _startFling(Velocity velocity) {
    if (_size.isEmpty) {
      return;
    }
    final normalized = Offset(velocity.pixelsPerSecond.dx / _size.width, velocity.pixelsPerSecond.dy / _size.height);
    if (normalized.distance < 0.3) {
      return;
    }
    _velocity = normalized;
    _lastTick = Duration.zero;
    _ticker.start();
  }

  @override
  Widget build(BuildContext context) {
    final canvas = ListenableBuilder(
      listenable: state,
      builder: (context, _) => CustomPaint(
        painter: _DemoPainter(state),
        child: const SizedBox.expand(),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // 標準行為：同時註冊 onTap 與 onDoubleTap 時，單擊要等約 300 ms 確認不是雙擊才觸發，雙擊不會再觸發單擊
          onTap: () => state.apply(_message('tap')),
          onDoubleTap: () => state.apply(_message('doubleTap')),
          onLongPress: () => state.apply(_message('longPress')),
          onSecondaryTap: () => state.apply(_message('longPress')),
          onScaleStart: (details) {
            _stopFling();
            state.beginScale();
          },
          onScaleUpdate: (details) {
            if (_size.isEmpty) {
              return;
            }
            // 多指時焦點會跟著手指中心移動，所以兩指縮放的同時也能平移
            state.moveBy(Offset(details.focalPointDelta.dx / _size.width, details.focalPointDelta.dy / _size.height));
            if (details.pointerCount >= 2) {
              state.scaleTo(details.scale, details.rotation);
            }
          },
          onScaleEnd: (details) {
            if (details.pointerCount == 0) {
              _startFling(details.velocity);
            }
          },
          child: canvas,
        );
      },
    );
  }
}

class _DemoPainter extends CustomPainter {
  _DemoPainter(this.state) : super(repaint: state);

  final MirrorDemoState state;

  @override
  void paint(Canvas canvas, Size size) {
    if (state.animating) {
      _paintVideoLike(canvas, size);
      return;
    }
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF14141C));
    final grid = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 1;
    for (var i = 1; i < 10; i++) {
      canvas.drawLine(Offset(size.width * i / 10, 0), Offset(size.width * i / 10, size.height), grid);
      canvas.drawLine(Offset(0, size.height * i / 10), Offset(size.width, size.height * i / 10), grid);
    }
    final center = Offset(state.center.dx * size.width, state.center.dy * size.height);
    final radius = state.radius * math.min(size.width, size.height);
    canvas.drawCircle(center, radius, Paint()..color = state.color);
    // 旋轉指示點：兩指旋轉時繞著圓緣移動
    canvas.drawCircle(
      center + Offset(math.cos(state.rotation), math.sin(state.rotation)) * radius * 0.8,
      radius * 0.09,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final text = TextPainter(
      text: TextSpan(
        text: '${state.count}',
        style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: radius, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  }

  /// 像影片的內容：滿版的色塊網格，每個格子的顏色隨時間連續變化，再加幾個移動的圓。每一幀每個像素幾乎都不同。
  void _paintVideoLike(Canvas canvas, Size size) {
    final t = state.timeSeconds;
    const columns = 48;
    final cell = size.width / columns;
    final paint = Paint();
    for (var row = 0; row * cell < size.height; row++) {
      for (var column = 0; column < columns; column++) {
        final hue = (math.sin(column * 0.31 + t * 2.1) + math.cos(row * 0.27 - t * 1.7) + 2) / 4 * 360;
        paint.color = HSVColor.fromAHSV(1, hue % 360, 0.75, 0.55 + 0.35 * math.sin(t * 3 + row * 0.2 + column * 0.1)).toColor();
        canvas.drawRect(Rect.fromLTWH(column * cell, row * cell, cell + 0.5, cell + 0.5), paint);
      }
    }
    for (var i = 0; i < 4; i++) {
      final angle = t * (0.8 + i * 0.35) + i * 1.7;
      final center = Offset(size.width * (0.5 + 0.38 * math.cos(angle)), size.height * (0.5 + 0.38 * math.sin(angle * 1.3)));
      canvas.drawCircle(center, size.shortestSide * 0.12, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85));
    }
  }

  @override
  bool shouldRepaint(_DemoPainter oldDelegate) => true;
}
