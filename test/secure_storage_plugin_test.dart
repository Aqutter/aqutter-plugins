import 'package:aqutter_plugin_secure_storage/aqutter_plugin_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ping echoes the message', () async {
    final plugin = SecureStoragePlugin();
    final result = await plugin.handlers['ping']!({'message': 'hi'});
    expect(result, {'echo': 'hi'});
  });

  test('id follows the naming rule', () {
    expect(SecureStoragePlugin().id, 'secure-storage');
  });
}
