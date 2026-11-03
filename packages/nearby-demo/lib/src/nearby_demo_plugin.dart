import 'package:aqutter/aqutter.dart';

/// 示範用的內部中間層：呼叫 `location`，把定位狀態與目前位置整理成一份快照。
///
/// 它是 [internal]：殼不對網頁註冊它的方法，只有別的 plugin 能經
/// `AqutterPluginContext.callPlugin('nearby-demo', 'snapshot')` 使用。
class NearbyDemoPlugin extends AqutterPlugin {
  AqutterPluginContext? _context;

  @override
  String get id => 'nearby-demo';

  @override
  bool get internal => true;

  @override
  Map<String, AqutterPluginHandler> get handlers => {'snapshot': _snapshot};

  @override
  void attach(AqutterPluginContext context) {
    _context = context;
  }

  @override
  void dispose() {
    _context = null;
  }

  Future<dynamic> _snapshot(Map<String, dynamic> _) async {
    final context = _context;
    if (context == null) {
      return aqutterErrorPayload('not_attached', 'nearby-demo is not attached yet');
    }
    final capabilities = await context.callPlugin('location', 'capabilities') as Map;
    final serviceEnabled = capabilities['serviceEnabled'] == true;
    final permission = capabilities['permission'] as String? ?? 'denied';

    Map<String, dynamic>? position;
    if (serviceEnabled && permission == 'granted') {
      try {
        final result = await context.callPlugin('location', 'getCurrentPosition', {'timeoutMs': 5000}) as Map;
        final fix = result['position'] as Map;
        position = {
          'latitude': fix['latitude'],
          'longitude': fix['longitude'],
          'accuracy': fix['accuracy'],
        };
      } on AqutterRpcException {
        // 逾時或暫時沒有定位：快照照回，position 為 null
        position = null;
      }
    }
    return {'serviceEnabled': serviceEnabled, 'permission': permission, 'position': position};
  }
}
