import 'package:aqutter/aqutter.dart';

/// 三層呼叫鏈的頂層：網頁 → `place-demo` → `nearby-demo`（internal）→ `location`。
///
/// 網頁只認識本 plugin；`nearby-demo` 與 `location` 的細節由這裡封裝。
class PlaceDemoPlugin extends AqutterPlugin {
  AqutterPluginContext? _context;

  @override
  String get id => 'place-demo';

  @override
  Map<String, AqutterPluginHandler> get handlers => {'whereAmI': _whereAmI};

  @override
  void attach(AqutterPluginContext context) {
    _context = context;
  }

  @override
  void dispose() {
    _context = null;
  }

  Future<dynamic> _whereAmI(Map<String, dynamic> _) async {
    final context = _context;
    if (context == null) {
      return aqutterErrorPayload('not_attached', 'place-demo is not attached yet');
    }
    final snapshot = await context.callPlugin('nearby-demo', 'snapshot') as Map;
    final permission = snapshot['permission'] as String? ?? 'denied';
    return {
      'layers': const ['place-demo', 'nearby-demo', 'location'],
      'ready': snapshot['serviceEnabled'] == true && permission == 'granted',
      'permission': permission,
      'position': snapshot['position'],
    };
  }
}
