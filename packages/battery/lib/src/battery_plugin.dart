import 'dart:async';

import 'package:aqutter/aqutter.dart';
import 'package:battery_plus/battery_plus.dart';

/// 電池 plugin：包裝 `battery_plus`，示範「網頁 API + 事件 + 相依既有 Flutter plugin」。
class BatteryPlugin extends AqutterPlugin {
  BatteryPlugin({Battery? battery}) : _battery = battery ?? Battery();

  final Battery _battery;
  StreamSubscription<BatteryState>? _subscription;

  @override
  String get id => 'battery';

  @override
  Map<String, AqutterPluginHandler> get handlers => {
        'level': (payload) async => {'level': await _battery.batteryLevel},
        'state': (payload) async => {'state': (await _battery.batteryState).name},
        'saveMode': (payload) async => {'enabled': await _battery.isInBatterySaveMode},
      };

  @override
  void attach(AqutterPluginContext context) {
    _subscription = _battery.onBatteryStateChanged.listen((state) {
      context.emit('stateChanged', {'state': state.name});
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
