import 'package:aqutter_plugin_haptics/aqutter_plugin_haptics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <String>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String? ?? 'vibrate');
      }
      return null;
    });
  });

  test('id follows the naming rule', () {
    expect(HapticsPlugin().id, 'haptics');
  });

  test('impact maps style to the matching haptic', () async {
    final impact = HapticsPlugin().handlers['impact']!;
    for (final style in ['light', 'medium', 'heavy']) {
      expect(await impact({'style': style}), {'ok': true});
    }
    expect(calls, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
  });

  test('impact rejects unknown styles', () async {
    expect(HapticsPlugin().handlers['impact']!({'style': 'x'}), throwsArgumentError);
  });

  test('selection and vibrate respond ok', () async {
    final handlers = HapticsPlugin().handlers;
    expect(await handlers['selection']!({}), {'ok': true});
    expect(await handlers['vibrate']!({}), {'ok': true});
  });
}
