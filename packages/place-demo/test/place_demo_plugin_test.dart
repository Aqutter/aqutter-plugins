import 'package:aqutter/aqutter.dart';
import 'package:aqutter_plugin_nearby_demo/aqutter_plugin_nearby_demo.dart';
import 'package:aqutter_plugin_place_demo/aqutter_plugin_place_demo.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('id follows the naming rule and the plugin is public', () {
    final plugin = PlaceDemoPlugin();
    expect(plugin.id, 'place-demo');
    expect(plugin.internal, isFalse);
  });

  test('three layers: place-demo reaches location through the internal nearby-demo', () async {
    final location = _Location();
    final nearby = NearbyDemoPlugin();
    final place = PlaceDemoPlugin();
    final context = _Context([place, nearby, location]);
    for (final plugin in [place, nearby]) {
      plugin.attach(context);
    }

    final result = await place.handlers['whereAmI']!(const {}) as Map;

    expect(result['layers'], ['place-demo', 'nearby-demo', 'location']);
    expect(result['ready'], isTrue);
    expect(result['permission'], 'granted');
    expect(result['position'], {'latitude': 25.0, 'longitude': 121.5, 'accuracy': 8.0});
    expect(location.calls, ['capabilities', 'getCurrentPosition']);
  });

  test('without the middle layer the error surfaces as PLUGIN_NOT_FOUND', () async {
    final place = PlaceDemoPlugin()..attach(_Context(const []));
    await expectLater(
      place.handlers['whereAmI']!(const {}),
      throwsA(isA<AqutterRpcException>().having((e) => e.code, 'code', 'PLUGIN_NOT_FOUND')),
    );
  });

  test('not ready when permission is missing', () async {
    final location = _Location(permission: 'denied');
    final place = PlaceDemoPlugin();
    final nearby = NearbyDemoPlugin();
    final context = _Context([place, nearby, location]);
    place.attach(context);
    nearby.attach(context);

    final result = await place.handlers['whereAmI']!(const {}) as Map;

    expect(result['ready'], isFalse);
    expect(result['position'], isNull);
  });
}

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
  _Location({this.permission = 'granted'});

  final String permission;
  final List<String> calls = [];

  @override
  String get id => 'location';

  @override
  Map<String, AqutterPluginHandler> get handlers => {
        'capabilities': (_) async {
          calls.add('capabilities');
          return {'serviceEnabled': true, 'permission': permission};
        },
        'getCurrentPosition': (_) async {
          calls.add('getCurrentPosition');
          return {
            'position': {'latitude': 25.0, 'longitude': 121.5, 'accuracy': 8.0},
          };
        },
      };
}
