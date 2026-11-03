import 'package:aqutter/aqutter.dart';
import 'package:aqutter_plugin_nearby_demo/aqutter_plugin_nearby_demo.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('is internal and named per the rule', () {
    final plugin = NearbyDemoPlugin();
    expect(plugin.id, 'nearby-demo');
    expect(plugin.internal, isTrue);
  });

  test('without a context the snapshot reports an error instead of throwing', () async {
    final result = await NearbyDemoPlugin().handlers['snapshot']!(const {});
    expect(aqutterErrorOf(result)?.code, 'not_attached');
  });

  test('returns the position when location is enabled and granted', () async {
    final plugin = _attach(_Location(serviceEnabled: true, permission: 'granted', fix: {'latitude': 25.0, 'longitude': 121.5, 'accuracy': 8.0}));
    expect(await plugin.handlers['snapshot']!(const {}), {
      'serviceEnabled': true,
      'permission': 'granted',
      'position': {'latitude': 25.0, 'longitude': 121.5, 'accuracy': 8.0},
    });
  });

  test('does not ask for a position without permission or with services off', () async {
    for (final location in [
      _Location(serviceEnabled: true, permission: 'denied'),
      _Location(serviceEnabled: false, permission: 'granted'),
    ]) {
      final result = await _attach(location).handlers['snapshot']!(const {}) as Map;
      expect(result['position'], isNull);
      expect(location.positionRequests, 0);
    }
  });

  test('a failed position request leaves position null and does not throw', () async {
    final plugin = _attach(_Location(serviceEnabled: true, permission: 'granted', fix: null));
    final result = await plugin.handlers['snapshot']!(const {}) as Map;
    expect(result['serviceEnabled'], isTrue);
    expect(result['position'], isNull);
  });

  test('a missing location plugin surfaces PLUGIN_NOT_FOUND', () async {
    final plugin = NearbyDemoPlugin()..attach(_Context(const []));
    await expectLater(
      plugin.handlers['snapshot']!(const {}),
      throwsA(isA<AqutterRpcException>().having((e) => e.code, 'code', 'PLUGIN_NOT_FOUND')),
    );
  });
}

NearbyDemoPlugin _attach(_Location location) => NearbyDemoPlugin()..attach(_Context([location]));

/// 把 `callPlugin` 接到殼同一份轉呼叫實作，所以測的是真正的呼叫路徑。
class _Context implements AqutterPluginContext {
  _Context(this.plugins);

  final List<AqutterPlugin> plugins;

  @override
  Future<dynamic> callPlugin(String pluginId, String method, [Map<String, dynamic> payload = const {}]) =>
      aqutterCallPlugin(plugins, TargetPlatform.android, pluginId, method, payload);

  @override
  Future<void> emit(String event, Object? payload) async {}

  @override
  Future<String> checkPermission(String type) async => 'granted';

  @override
  Future<String> requestPermission(String type) async => 'granted';

  @override
  Future<void> openPermissionSettings() async {}
}

class _Location extends AqutterPlugin {
  _Location({required this.serviceEnabled, required this.permission, this.fix});

  final bool serviceEnabled;
  final String permission;
  final Map<String, dynamic>? fix;
  int positionRequests = 0;

  @override
  String get id => 'location';

  @override
  Map<String, AqutterPluginHandler> get handlers => {
        'capabilities': (_) async => {'serviceEnabled': serviceEnabled, 'permission': permission},
        'getCurrentPosition': (_) async {
          positionRequests += 1;
          final value = fix;
          return value == null ? aqutterErrorPayload('timeout', 'no fix') : {'position': value};
        },
      };
}
