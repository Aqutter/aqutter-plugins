import 'package:aqutter_plugin_location/aqutter_plugin_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ping echoes the message', () async {
    final plugin = LocationPlugin();
    final result = await plugin.handlers['ping']!({'message': 'hi'});
    expect(result, {'echo': 'hi'});
  });

  test('id follows the naming rule', () {
    expect(LocationPlugin().id, 'location');
  });
}
