import 'dart:io';
import 'dart:typed_data';

import 'package:aqutter/aqutter.dart';
import 'package:aqutter_plugin_file_manager/aqutter_plugin_file_manager.dart';
import 'package:aqutter_plugin_file_manager/src/location.dart';
import 'package:aqutter_plugin_file_manager/src/media_saver.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';

Uint8List _bytes(String text) => Uint8List.fromList(text.codeUnits);

class _FakeGallery implements GalleryWriter {
  _FakeGallery({this.denied = false});

  final bool denied;
  final List<(Uint8List, String)> saved = [];

  @override
  Future<void> putImage(Uint8List bytes, String name) async {
    if (denied) {
      throw const FileManagerException(errPermissionDenied, 'no access');
    }
    saved.add((bytes, name));
  }
}

class _FakeDialog implements FileSaveDialog {
  _FakeDialog({this.cancel = false});

  final bool cancel;
  final List<(Uint8List, String, String)> saved = [];

  @override
  Future<bool> save(Uint8List bytes, String name, String mimeType) async {
    if (cancel) {
      return false;
    }
    saved.add((bytes, name, mimeType));
    return true;
  }
}

final Uint8List _png = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0]);
final Uint8List _jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 0, 0]);

void main() {
  group('parseLocation', () {
    test('splits a sandbox location into root and segments', () {
      final location = parseLocation('app-documents:報表/2026/a.pdf');
      expect(location.root, 'app-documents');
      expect(location.segments, ['報表', '2026', 'a.pdf']);
    });

    test('a bare root is the root itself', () {
      expect(parseLocation('app-cache:').isRoot, isTrue);
    });

    test('a granted location carries the grant id', () {
      final location = parseLocation('granted:abc-1/sub/x.txt');
      expect(location.grantId, 'abc-1');
      expect(location.segments, ['sub', 'x.txt']);
    });

    test('rejects everything that is not a well-formed relative path', () {
      for (final bad in [
        '',
        'nothing',
        'unknown-root:a',
        'app-cache:../x',
        'app-cache:a/../x',
        'app-cache:/abs',
        'app-cache:a//b',
        'app-cache:a/',
        'app-cache:a\\b',
        'app-cache:a\u0000b',
        'app-cache:${'x' * 256}',
        'granted:bad id/x',
        'granted:',
      ]) {
        expect(() => parseLocation(bad), throwsA(isA<FileManagerException>().having((e) => e.code, 'code', errInvalidPath)), reason: bad);
      }
      expect(() => parseLocation(5), throwsA(isA<FileManagerException>()));
    });

    test('rejects a path longer than 1024 characters', () {
      final long = List.filled(30, 'a' * 40).join('/');
      expect(() => parseLocation('app-cache:$long'), throwsA(isA<FileManagerException>()));
    });
  });

  group('FileManagerPlugin (sandbox)', () {
    late Directory temp;
    late FileManagerPlugin plugin;

    Future<dynamic> call(String method, Map<String, dynamic> payload) => plugin.handlers[method]!(payload);

    void expectError(dynamic result, String code) {
      final error = aqutterErrorOf(result);
      expect(error, isNotNull, reason: 'expected $code, got $result');
      expect(error!.code, code);
    }

    setUp(() {
      temp = Directory.systemTemp.createTempSync('file-manager-test');
      plugin = FileManagerPlugin(rootResolver: (root) async {
        final dir = Directory('${temp.path}/$root')..createSync(recursive: true);
        return dir;
      });
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test('id and the implemented handlers', () {
      expect(plugin.id, 'file-manager');
      expect(plugin.handlers.keys, containsAll(['list', 'stat', 'read', 'write', 'makeDirectory', 'copy', 'move', 'delete']));
    });

    test('write, stat, read and list round-trip', () async {
      final written = await call('write', {'location': 'app-documents:a.txt', 'data': _bytes('hello'), 'mode': 'create'});
      expect(written, {'size': 5});

      final stat = await call('stat', {'location': 'app-documents:a.txt'}) as Map;
      expect(stat['exists'], isTrue);
      expect(stat['kind'], 'file');
      expect(stat['size'], 5);

      final read = await call('read', {'location': 'app-documents:a.txt'}) as Map;
      expect(String.fromCharCodes(read['data'] as Uint8List), 'hello');
      expect(read['eof'], isTrue);

      final listed = await call('list', {'location': 'app-documents:'}) as Map;
      expect((listed['entries'] as List).map((e) => (e as Map)['name']), ['a.txt']);
    });

    test('stat of something missing reports exists false instead of failing', () async {
      expect(await call('stat', {'location': 'app-cache:nope'}), {'exists': false});
    });

    test('write modes: create refuses an existing file, overwrite replaces, append extends', () async {
      await call('write', {'location': 'app-cache:f', 'data': _bytes('one'), 'mode': 'create'});
      expectError(await call('write', {'location': 'app-cache:f', 'data': _bytes('x'), 'mode': 'create'}), errAlreadyExists);

      await call('write', {'location': 'app-cache:f', 'data': _bytes('two'), 'mode': 'overwrite'});
      expect(await call('write', {'location': 'app-cache:f', 'data': _bytes('+3'), 'mode': 'append'}), {'size': 5});
      expect(String.fromCharCodes((await call('read', {'location': 'app-cache:f'}) as Map)['data'] as Uint8List), 'two+3');
    });

    test('write needs an existing parent folder and rejects a bad mode or data', () async {
      expectError(await call('write', {'location': 'app-cache:no/dir/f', 'data': _bytes('x'), 'mode': 'create'}), errNotFound);
      expectError(await call('write', {'location': 'app-cache:f', 'data': _bytes('x'), 'mode': 'weird'}), errInvalidPath);
      expectError(await call('write', {'location': 'app-cache:f', 'data': 'text', 'mode': 'create'}), errInvalidPath);
    });

    test('content over 5 MiB is refused for write and for read length', () async {
      expectError(await call('write', {'location': 'app-cache:big', 'data': Uint8List(maxContentBytes + 1), 'mode': 'create'}), errTooLarge);
      await call('write', {'location': 'app-cache:ok', 'data': _bytes('x'), 'mode': 'create'});
      expectError(await call('read', {'location': 'app-cache:ok', 'length': maxContentBytes + 1}), errTooLarge);
    });

    test('a large file is read in chunks with offset and length until eof', () async {
      await call('write', {'location': 'app-cache:chunks', 'data': _bytes('0123456789'), 'mode': 'create'});

      final first = await call('read', {'location': 'app-cache:chunks', 'offset': 0, 'length': 4}) as Map;
      expect(String.fromCharCodes(first['data'] as Uint8List), '0123');
      expect(first['eof'], isFalse);

      final last = await call('read', {'location': 'app-cache:chunks', 'offset': 8, 'length': 4}) as Map;
      expect(String.fromCharCodes(last['data'] as Uint8List), '89');
      expect(last['eof'], isTrue);

      final beyond = await call('read', {'location': 'app-cache:chunks', 'offset': 99}) as Map;
      expect((beyond['data'] as Uint8List), isEmpty);
      expect(beyond['eof'], isTrue);
    });

    test('read reports missing files and folders', () async {
      expectError(await call('read', {'location': 'app-cache:none'}), errNotFound);
      await call('makeDirectory', {'location': 'app-cache:d'});
      expectError(await call('read', {'location': 'app-cache:d'}), errIsADirectory);
    });

    test('makeDirectory: recursive creates parents, plain needs the parent, repeating fails unless recursive', () async {
      expectError(await call('makeDirectory', {'location': 'app-cache:a/b'}), errNotFound);
      await call('makeDirectory', {'location': 'app-cache:a/b', 'recursive': true});
      expectError(await call('makeDirectory', {'location': 'app-cache:a'}), errAlreadyExists);
      await call('makeDirectory', {'location': 'app-cache:a', 'recursive': true});
      expect((await call('list', {'location': 'app-cache:a'}) as Map)['entries'], hasLength(1));
    });

    test('list sorts by name and marks folders without a size', () async {
      await call('makeDirectory', {'location': 'app-cache:zdir'});
      await call('write', {'location': 'app-cache:b.txt', 'data': _bytes('b'), 'mode': 'create'});
      await call('write', {'location': 'app-cache:a.txt', 'data': _bytes('a'), 'mode': 'create'});

      final entries = (await call('list', {'location': 'app-cache:'}) as Map)['entries'] as List;
      expect(entries.map((e) => (e as Map)['name']), ['a.txt', 'b.txt', 'zdir']);
      expect((entries.last as Map)['kind'], 'directory');
      expect((entries.last as Map).containsKey('size'), isFalse);
      expectError(await call('list', {'location': 'app-cache:a.txt'}), errNotADirectory);
      expectError(await call('list', {'location': 'app-cache:missing'}), errNotFound);
    });

    test('copy and move work for files and whole folders, and refuse to clobber unless overwrite', () async {
      await call('makeDirectory', {'location': 'app-cache:src/inner', 'recursive': true});
      await call('write', {'location': 'app-cache:src/inner/f', 'data': _bytes('data'), 'mode': 'create'});

      await call('copy', {'from': 'app-cache:src', 'to': 'app-cache:dst'});
      expect((await call('stat', {'location': 'app-cache:dst/inner/f'}) as Map)['exists'], isTrue);
      expect((await call('stat', {'location': 'app-cache:src/inner/f'}) as Map)['exists'], isTrue);

      expectError(await call('copy', {'from': 'app-cache:src', 'to': 'app-cache:dst'}), errAlreadyExists);
      await call('copy', {'from': 'app-cache:src', 'to': 'app-cache:dst', 'overwrite': true});

      await call('move', {'from': 'app-cache:dst', 'to': 'app-cache:moved'});
      expect((await call('stat', {'location': 'app-cache:dst'}) as Map)['exists'], isFalse);
      expect((await call('stat', {'location': 'app-cache:moved/inner/f'}) as Map)['exists'], isTrue);
    });

    test('copy and move refuse the root, a missing source, a missing target parent and a target inside the source', () async {
      await call('makeDirectory', {'location': 'app-cache:src'});
      expectError(await call('copy', {'from': 'app-cache:', 'to': 'app-cache:x'}), errInvalidPath);
      expectError(await call('move', {'from': 'app-cache:missing', 'to': 'app-cache:x'}), errNotFound);
      expectError(await call('copy', {'from': 'app-cache:src', 'to': 'app-cache:no/parent/x'}), errNotFound);
      expectError(await call('move', {'from': 'app-cache:src', 'to': 'app-cache:src/inside'}), errInvalidPath);
    });

    test('copy and move across roots are refused', () async {
      await call('write', {'location': 'app-cache:f', 'data': _bytes('x'), 'mode': 'create'});

      expectError(await call('copy', {'from': 'app-cache:f', 'to': 'app-documents:f'}), errCrossRoot);
      expectError(await call('move', {'from': 'app-cache:f', 'to': 'app-documents:f'}), errCrossRoot);
    });

    test('delete: a non-empty folder needs recursive, the root can never be deleted', () async {
      await call('makeDirectory', {'location': 'app-cache:d'});
      await call('write', {'location': 'app-cache:d/f', 'data': _bytes('x'), 'mode': 'create'});

      expectError(await call('delete', {'location': 'app-cache:d'}), errNotEmpty);
      await call('delete', {'location': 'app-cache:d', 'recursive': true});
      expect((await call('stat', {'location': 'app-cache:d'}) as Map)['exists'], isFalse);

      expectError(await call('delete', {'location': 'app-cache:'}), errInvalidPath);
      expectError(await call('delete', {'location': 'app-cache:gone'}), errNotFound);
    });

    test('a granted location with no such grant is not found', () async {
      expectError(await call('list', {'location': 'granted:abc'}), errNotFound);
    });

    test('bad locations come back as invalid_path errors, not exceptions', () async {
      expectError(await call('list', {'location': 'app-cache:../etc'}), errInvalidPath);
      expectError(await call('read', {'location': 7}), errInvalidPath);
    });

    test('a symlink that points outside the root cannot be followed', () async {
      final outside = Directory('${temp.path}/outside')..createSync();
      File('${outside.path}/secret').writeAsStringSync('secret');
      final cache = Directory('${temp.path}/app-cache')..createSync(recursive: true);
      try {
        Link('${cache.path}/escape').createSync(outside.path);
      }
      on FileSystemException {
        markTestSkipped('this system does not allow creating symlinks');
        return;
      }

      expectError(await call('read', {'location': 'app-cache:escape/secret'}), errInvalidPath);
      expectError(await call('list', {'location': 'app-cache:escape'}), errInvalidPath);
      expect(File('${outside.path}/secret').existsSync(), isTrue);
    });
  });

  group('saveToGallery', () {
    Future<dynamic> save(FileManagerPlugin plugin, Map<String, dynamic> payload) => plugin.handlers['saveToGallery']!(payload);

    void expectError(dynamic result, String code) {
      final error = aqutterErrorOf(result);
      expect(error, isNotNull, reason: 'expected $code, got $result');
      expect(error!.code, code);
    }

    test('saves a PNG and a JPEG, handing the gallery the name without its extension', () async {
      final gallery = _FakeGallery();
      final plugin = FileManagerPlugin(gallery: gallery);

      expect(await save(plugin, {'data': _png, 'name': 'logo.png', 'mimeType': 'image/png'}), {'status': 'saved'});
      expect(await save(plugin, {'data': _jpeg, 'name': 'photo', 'mimeType': 'image/jpeg'}), {'status': 'saved'});

      expect(gallery.saved.map((item) => item.$2), ['logo', 'photo']);
    });

    test('is only available on Android and iOS, the other methods on every platform', () {
      final plugin = FileManagerPlugin();

      expect(plugin.supportedPlatformsFor('saveToGallery'), {TargetPlatform.android, TargetPlatform.iOS});
      expect(plugin.supportedPlatformsFor('list'), isNull);
    });

    test('rejects a bad name, a missing or oversized payload and an unsupported type', () async {
      final plugin = FileManagerPlugin(gallery: _FakeGallery());

      for (final name in ['', '.', '..', 'a/b.png', 'a\b.png', 'a .png', 'x' * 256]) {
        expectError(await save(plugin, {'data': _png, 'name': name, 'mimeType': 'image/png'}), errInvalidPath);
      }
      expectError(await save(plugin, {'name': 'a.png', 'mimeType': 'image/png'}), errInvalidPath);
      expectError(await save(plugin, {'data': Uint8List(maxContentBytes + 1), 'name': 'a.png', 'mimeType': 'image/png'}), errTooLarge);
      expectError(await save(plugin, {'data': _png, 'name': 'a.gif', 'mimeType': 'image/gif'}), errInvalidPath);
    });

    test('the bytes must really be the declared image type', () async {
      final plugin = FileManagerPlugin(gallery: _FakeGallery());

      expectError(await save(plugin, {'data': _jpeg, 'name': 'a.png', 'mimeType': 'image/png'}), errInvalidPath);
      expectError(await save(plugin, {'data': _bytes('not an image'), 'name': 'a.png', 'mimeType': 'image/png'}), errInvalidPath);
    });

    test('a refused gallery permission comes back as permission_denied', () async {
      final plugin = FileManagerPlugin(gallery: _FakeGallery(denied: true));

      expectError(await save(plugin, {'data': _png, 'name': 'a.png', 'mimeType': 'image/png'}), errPermissionDenied);
    });
  });

  group('saveToDownloads', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('file-manager-dl'));
    tearDown(() => temp.deleteSync(recursive: true));

    FileManagerPlugin make(_FakeDialog dialog, {TargetPlatform platform = TargetPlatform.android}) {
      return FileManagerPlugin(
        saveDialog: dialog,
        platform: platform,
        rootResolver: (root) async => Directory('${temp.path}/$root')..createSync(recursive: true),
      );
    }

    Future<dynamic> save(FileManagerPlugin plugin, Map<String, dynamic> payload) => plugin.handlers['saveToDownloads']!(payload);

    void expectError(dynamic result, String code) {
      final error = aqutterErrorOf(result);
      expect(error, isNotNull, reason: 'expected $code, got $result');
      expect(error!.code, code);
    }

    test('saves given bytes through the dialog; the result is saved, or exported on iOS', () async {
      final dialog = _FakeDialog();

      final android = await save(make(dialog), {'data': _bytes('report'), 'name': 'r.pdf', 'mimeType': 'application/pdf'});
      final ios = await save(make(dialog, platform: TargetPlatform.iOS), {'data': _bytes('report'), 'name': 'r.pdf', 'mimeType': 'application/pdf'});

      expect(android, {'status': 'saved'});
      expect(ios, {'status': 'exported'});
      expect(dialog.saved.first.$2, 'r.pdf');
      expect(dialog.saved.first.$3, 'application/pdf');
    });

    test('a cancelled dialog is reported as cancelled, not as a failure', () async {
      final result = await save(make(_FakeDialog(cancel: true)), {'data': _bytes('x'), 'name': 'a.txt', 'mimeType': 'text/plain'});

      expect(result, {'status': 'cancelled'});
    });

    test('from reads a file in the app folder, including one larger than the 5 MiB bridge limit', () async {
      final dialog = _FakeDialog();
      final plugin = make(dialog);
      final big = Uint8List(maxContentBytes + 10);
      File('${temp.path}/app-documents/big.bin')
        ..createSync(recursive: true)
        ..writeAsBytesSync(big);

      final result = await save(plugin, {'from': 'app-documents:big.bin', 'name': 'big.bin', 'mimeType': 'application/octet-stream'});

      expect(result, {'status': 'saved'});
      expect(dialog.saved.single.$1.length, big.length);
    });

    test('from reports a missing file and a bad location', () async {
      final plugin = make(_FakeDialog());

      expectError(await save(plugin, {'from': 'app-documents:none', 'name': 'a', 'mimeType': 'text/plain'}), errNotFound);
      expectError(await save(plugin, {'from': '../x', 'name': 'a', 'mimeType': 'text/plain'}), errInvalidPath);
    });

    test('exactly one of data and from is required', () async {
      final plugin = make(_FakeDialog());

      expectError(await save(plugin, {'name': 'a', 'mimeType': 'text/plain'}), errInvalidPath);
      expectError(await save(plugin, {'data': _bytes('x'), 'from': 'app-cache:a', 'name': 'a', 'mimeType': 'text/plain'}), errInvalidPath);
    });

    test('rejects oversized data, a bad name and a bad media type', () async {
      final plugin = make(_FakeDialog());

      expectError(await save(plugin, {'data': Uint8List(maxContentBytes + 1), 'name': 'a', 'mimeType': 'text/plain'}), errTooLarge);
      expectError(await save(plugin, {'data': _bytes('x'), 'name': '../a', 'mimeType': 'text/plain'}), errInvalidPath);
      expectError(await save(plugin, {'data': _bytes('x'), 'name': 'a', 'mimeType': 'nonsense'}), errInvalidPath);
      expectError(await save(plugin, {'data': _bytes('x'), 'name': 'a', 'mimeType': 7}), errInvalidPath);
    });
  });
}
