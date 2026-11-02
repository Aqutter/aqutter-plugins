import 'package:aqutter_plugin_battery/aqutter_plugin_battery.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.fluttercommunity.plus/battery');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getBatteryLevel':
          return 87;
        case 'getBatteryState':
          return 'charging';
        case 'isInBatterySaveMode':
          return true;
      }
      return null;
    });
  });

  test('id follows the naming rule', () {
    expect(BatteryPlugin().id, 'battery');
  });

  test('level reports the platform value', () async {
    expect(await BatteryPlugin().handlers['level']!({}), {'level': 87});
  });

  test('state reports the enum name', () async {
    expect(await BatteryPlugin().handlers['state']!({}), {'state': 'charging'});
  });

  test('saveMode reports the flag', () async {
    expect(await BatteryPlugin().handlers['saveMode']!({}), {'enabled': true});
  });
}
