import 'package:aqutter_plugin_biometrics/aqutter_plugin_biometrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ping echoes the message', () async {
    final plugin = BiometricsPlugin();
    final result = await plugin.handlers['ping']!({'message': 'hi'});
    expect(result, {'echo': 'hi'});
  });

  test('id follows the naming rule', () {
    expect(BiometricsPlugin().id, 'biometrics');
  });
}
