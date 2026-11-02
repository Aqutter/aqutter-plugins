import 'package:aqutter/aqutter.dart';
import 'package:flutter/services.dart';

/// 觸覺回饋 plugin：只用 Flutter 內建的 [HapticFeedback]，不需要任何原生程式碼。
class HapticsPlugin extends AqutterPlugin {
  @override
  String get id => 'haptics';

  @override
  Map<String, AqutterPluginHandler> get handlers => {
        'impact': (payload) async {
          switch (payload['style']) {
            case 'light':
              await HapticFeedback.lightImpact();
            case 'heavy':
              await HapticFeedback.heavyImpact();
            case 'medium':
              await HapticFeedback.mediumImpact();
            default:
              throw ArgumentError.value(payload['style'], 'style', 'Expected light / medium / heavy');
          }
          return {'ok': true};
        },
        'selection': (payload) async {
          await HapticFeedback.selectionClick();
          return {'ok': true};
        },
        'vibrate': (payload) async {
          await HapticFeedback.vibrate();
          return {'ok': true};
        },
      };
}
