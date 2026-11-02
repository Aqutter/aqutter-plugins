import 'dart:typed_data';

import 'package:aqutter/aqutter.dart';
import 'package:aqutter_plugin_file_manager/aqutter_plugin_file_manager.dart';
import 'package:aqutter_plugin_file_manager/src/grants.dart';
import 'package:aqutter_plugin_file_manager/src/location.dart';
import 'package:aqutter_plugin_file_manager/src/saf_file_ops.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';

Uint8List _bytes(String text) => Uint8List.fromList(text.codeUnits);

String _text(Object? data) => String.fromCharCodes(data as Uint8List);

class _Node {
  _Node(this.name, this.isDir, {Uint8List? data}) : data = data ?? Uint8List(0);

  String name;
  final bool isDir;
  Uint8List data;
  final Map<String, _Node> children = {};

  _Node copy() {
    final clone = _Node(name, isDir, data: Uint8List.fromList(data));
    for (final entry in children.entries) {
      clone.children[entry.key] = entry.value.copy();
    }
    return clone;
  }
}

/// 記憶體內的 SAF 樹：文件編號是 `content://tree/<路徑>`。
class _FakeSaf implements SafBackend {
  static const String tree = 'content://tree';

  final _Node root = _Node('shared', true);
  SafEntry? picked;
  bool revoked = false;

  List<String> _path(String uri) => uri == tree ? [] : uri.substring(tree.length + 1).split('/');

  String _uriOf(List<String> path) => path.isEmpty ? tree : '$tree/${path.join('/')}';

  _Node? _walk(List<String> path) {
    var node = root;
    for (final name in path) {
      final next = node.children[name];
      if (next == null || !node.isDir) {
        return null;
      }
      node = next;
    }
    return node;
  }

  SafEntry _entry(List<String> path, _Node node) {
    return SafEntry(uri: _uriOf(path), name: node.name, isDir: node.isDir, length: node.isDir ? -1 : node.data.length, modified: 1000);
  }

  void _requireAccess() {
    if (revoked) {
      throw StateError('permission revoked');
    }
  }

  @override
  Future<SafEntry?> pickDirectory() async => picked;

  @override
  Future<SafEntry?> child(String treeUri, List<String> names) async {
    _requireAccess();
    final path = [..._path(treeUri), ...names];
    final node = _walk(path);
    return node == null ? null : _entry(path, node);
  }

  @override
  Future<List<SafEntry>> list(String dirUri) async {
    final path = _path(dirUri);
    return [for (final entry in _walk(path)!.children.entries) _entry([...path, entry.key], entry.value)];
  }

  @override
  Future<SafEntry> mkdirp(String treeUri, List<String> names) async {
    var path = _path(treeUri);
    var node = _walk(path)!;
    for (final name in names) {
      path = [...path, name];
      node = node.children.putIfAbsent(name, () => _Node(name, true));
    }
    return _entry(path, node);
  }

  @override
  Future<void> delete(String uri, bool isDir) async {
    final path = _path(uri);
    _walk(path.sublist(0, path.length - 1))!.children.remove(path.last);
  }

  @override
  Future<SafEntry> rename(String uri, bool isDir, String newName) async {
    final path = _path(uri);
    final parent = _walk(path.sublist(0, path.length - 1))!;
    final node = parent.children.remove(path.last)!;
    node.name = newName;
    parent.children[newName] = node;
    return _entry([...path.sublist(0, path.length - 1), newName], node);
  }

  @override
  Future<SafEntry> moveTo(String uri, bool isDir, String parentUri, String newParentUri) async {
    final path = _path(uri);
    final node = _walk(_path(parentUri))!.children.remove(path.last)!;
    final target = _walk(_path(newParentUri))!;
    target.children[node.name] = node;
    return _entry([..._path(newParentUri), node.name], node);
  }

  @override
  Future<SafEntry> copyTo(String uri, bool isDir, String newParentUri) async {
    final node = _walk(_path(uri))!.copy();
    final target = _walk(_path(newParentUri))!;
    var name = node.name;
    while (target.children.containsKey(name)) {
      name = '$name (1)';
    }
    node.name = name;
    target.children[name] = node;
    return _entry([..._path(newParentUri), name], node);
  }

  @override
  Future<Uint8List> read(String uri, {int? start, int? count}) async {
    final data = _walk(_path(uri))!.data;
    final from = start ?? 0;
    final to = count == null ? data.length : (from + count).clamp(0, data.length);
    return Uint8List.fromList(data.sublist(from.clamp(0, data.length), to));
  }

  @override
  Future<SafEntry> write(String parentUri, String name, String mime, Uint8List data, {bool overwrite = false, bool append = false}) async {
    final parentPath = _path(parentUri);
    final parent = _walk(parentPath)!;
    final existing = parent.children[name];
    if (existing != null && append) {
      existing.data = Uint8List.fromList([...existing.data, ...data]);
      return _entry([...parentPath, name], existing);
    }
    final node = _Node(name, false, data: data);
    parent.children[name] = node;
    return _entry([...parentPath, name], node);
  }
}

void main() {
  late _FakeSaf saf;
  late FileManagerPlugin plugin;
  late String id;

  Future<dynamic> call(String method, Map<String, dynamic> payload) => plugin.handlers[method]!(payload);

  void expectError(dynamic result, String code) {
    final error = aqutterErrorOf(result);
    expect(error, isNotNull, reason: 'expected $code, got $result');
    expect(error!.code, code);
  }

  setUp(() async {
    saf = _FakeSaf();
    saf.picked = SafEntry(uri: _FakeSaf.tree, name: 'shared', isDir: true, length: -1, modified: 0);
    plugin = FileManagerPlugin(
      grants: GrantManager(store: _MemoryStore(), safBackend: saf, platform: TargetPlatform.android),
    );
    id = (((await call('grant', {'kind': 'directory'}) as Map)['grants'] as List).single as Map)['id'] as String;
  });

  test('grant on Android picks a directory and never reveals the tree URI', () async {
    final entry = ((await call('grants', {}) as Map)['grants'] as List).single as Map;

    expect(entry.keys, unorderedEquals(['id', 'name', 'kind']));
    expect(entry.values.join(), isNot(contains('content://')));
  });

  test('a cancelled directory picker grants nothing', () async {
    saf.picked = null;

    expect(await call('grant', {'kind': 'directory'}), {'grants': []});
  });

  test('file and files grants are not supported on Android', () async {
    expectError(await call('grant', {'kind': 'file'}), aqutterUnsupportedPlatform);
    expectError(await call('grant', {'kind': 'files'}), aqutterUnsupportedPlatform);
  });

  test('grant, grants and revoke are listed as supported on Android', () {
    for (final method in ['grant', 'grants', 'revoke']) {
      expect(plugin.supportedPlatformsFor(method), contains(TargetPlatform.android));
    }
  });

  test('write, stat, read and list round-trip inside the granted tree', () async {
    await call('makeDirectory', {'location': 'granted:$id/docs'});
    expect(await call('write', {'location': 'granted:$id/docs/a.txt', 'data': _bytes('hello'), 'mode': 'create'}), {'size': 5});

    final stat = await call('stat', {'location': 'granted:$id/docs/a.txt'}) as Map;
    expect(stat['exists'], isTrue);
    expect(stat['kind'], 'file');
    expect(stat['size'], 5);

    expect(_text((await call('read', {'location': 'granted:$id/docs/a.txt'}) as Map)['data']), 'hello');
    final listed = (await call('list', {'location': 'granted:$id/docs'}) as Map)['entries'] as List;
    expect(listed.map((e) => (e as Map)['name']), ['a.txt']);
    expect(await call('stat', {'location': 'granted:$id/none'}), {'exists': false});
  });

  test('write modes and their errors', () async {
    await call('write', {'location': 'granted:$id/f', 'data': _bytes('one'), 'mode': 'create'});

    expectError(await call('write', {'location': 'granted:$id/f', 'data': _bytes('x'), 'mode': 'create'}), errAlreadyExists);
    await call('write', {'location': 'granted:$id/f', 'data': _bytes('two'), 'mode': 'overwrite'});
    expect(await call('write', {'location': 'granted:$id/f', 'data': _bytes('+3'), 'mode': 'append'}), {'size': 5});
    expect(_text((await call('read', {'location': 'granted:$id/f'}) as Map)['data']), 'two+3');

    expectError(await call('write', {'location': 'granted:$id/no/dir/f', 'data': _bytes('x'), 'mode': 'create'}), errNotFound);
    await call('makeDirectory', {'location': 'granted:$id/d'});
    expectError(await call('write', {'location': 'granted:$id/d', 'data': _bytes('x'), 'mode': 'overwrite'}), errIsADirectory);
    expectError(await call('write', {'location': 'granted:$id', 'data': _bytes('x'), 'mode': 'overwrite'}), errInvalidPath);
    expectError(await call('write', {'location': 'granted:$id/g', 'data': _bytes('x'), 'mode': 'bogus'}), errInvalidPath);
  });

  test('chunked reads report eof, and reading past the end is empty', () async {
    await call('write', {'location': 'granted:$id/c', 'data': _bytes('0123456789'), 'mode': 'create'});

    final first = await call('read', {'location': 'granted:$id/c', 'offset': 0, 'length': 4}) as Map;
    expect(_text(first['data']), '0123');
    expect(first['eof'], isFalse);

    final last = await call('read', {'location': 'granted:$id/c', 'offset': 8, 'length': 4}) as Map;
    expect(_text(last['data']), '89');
    expect(last['eof'], isTrue);

    expect((await call('read', {'location': 'granted:$id/c', 'offset': 99}) as Map)['data'], isEmpty);
    expectError(await call('read', {'location': 'granted:$id/c', 'length': maxContentBytes + 1}), errTooLarge);
  });

  test('list, read and delete report the right errors', () async {
    await call('makeDirectory', {'location': 'granted:$id/d'});
    await call('write', {'location': 'granted:$id/d/f', 'data': _bytes('x'), 'mode': 'create'});

    expectError(await call('list', {'location': 'granted:$id/d/f'}), errNotADirectory);
    expectError(await call('list', {'location': 'granted:$id/none'}), errNotFound);
    expectError(await call('read', {'location': 'granted:$id/d'}), errIsADirectory);
    expectError(await call('read', {'location': 'granted:$id/none'}), errNotFound);
    expectError(await call('delete', {'location': 'granted:$id/d'}), errNotEmpty);
    expectError(await call('delete', {'location': 'granted:$id'}), errInvalidPath);
    expectError(await call('delete', {'location': 'granted:$id/none'}), errNotFound);

    await call('delete', {'location': 'granted:$id/d', 'recursive': true});
    expect(await call('stat', {'location': 'granted:$id/d'}), {'exists': false});
  });

  test('makeDirectory: recursive creates the chain, plain needs the parent, repeating fails unless recursive', () async {
    expectError(await call('makeDirectory', {'location': 'granted:$id/a/b'}), errNotFound);
    await call('makeDirectory', {'location': 'granted:$id/a/b', 'recursive': true});
    expectError(await call('makeDirectory', {'location': 'granted:$id/a'}), errAlreadyExists);
    await call('makeDirectory', {'location': 'granted:$id/a', 'recursive': true});
  });

  test('copy keeps the source and renames the copy; move renames or relocates', () async {
    await call('makeDirectory', {'location': 'granted:$id/src', 'recursive': true});
    await call('write', {'location': 'granted:$id/src/f', 'data': _bytes('data'), 'mode': 'create'});
    await call('makeDirectory', {'location': 'granted:$id/dst'});

    await call('copy', {'from': 'granted:$id/src/f', 'to': 'granted:$id/dst/copy'});
    expect(_text((await call('read', {'location': 'granted:$id/dst/copy'}) as Map)['data']), 'data');
    expect((await call('stat', {'location': 'granted:$id/src/f'}) as Map)['exists'], isTrue);

    await call('move', {'from': 'granted:$id/src/f', 'to': 'granted:$id/src/renamed'});
    expect((await call('stat', {'location': 'granted:$id/src/f'}) as Map)['exists'], isFalse);
    expect((await call('stat', {'location': 'granted:$id/src/renamed'}) as Map)['exists'], isTrue);

    await call('move', {'from': 'granted:$id/src/renamed', 'to': 'granted:$id/dst/moved'});
    expect((await call('stat', {'location': 'granted:$id/dst/moved'}) as Map)['exists'], isTrue);
  });

  test('copy of a folder takes its content along', () async {
    await call('makeDirectory', {'location': 'granted:$id/src/inner', 'recursive': true});
    await call('write', {'location': 'granted:$id/src/inner/f', 'data': _bytes('x'), 'mode': 'create'});

    await call('copy', {'from': 'granted:$id/src', 'to': 'granted:$id/dup'});

    expect((await call('stat', {'location': 'granted:$id/dup/inner/f'}) as Map)['exists'], isTrue);
  });

  test('copy and move refuse to clobber unless overwrite, and refuse bad targets', () async {
    await call('write', {'location': 'granted:$id/a', 'data': _bytes('a'), 'mode': 'create'});
    await call('write', {'location': 'granted:$id/b', 'data': _bytes('b'), 'mode': 'create'});
    await call('makeDirectory', {'location': 'granted:$id/d'});

    expectError(await call('copy', {'from': 'granted:$id/a', 'to': 'granted:$id/b'}), errAlreadyExists);
    await call('copy', {'from': 'granted:$id/a', 'to': 'granted:$id/b', 'overwrite': true});
    expect(_text((await call('read', {'location': 'granted:$id/b'}) as Map)['data']), 'a');

    expectError(await call('move', {'from': 'granted:$id/none', 'to': 'granted:$id/x'}), errNotFound);
    expectError(await call('copy', {'from': 'granted:$id', 'to': 'granted:$id/x'}), errInvalidPath);
    expectError(await call('move', {'from': 'granted:$id/d', 'to': 'granted:$id/d/inside'}), errInvalidPath);
    expectError(await call('copy', {'from': 'granted:$id/a', 'to': 'granted:$id/no/parent/x'}), errNotFound);
  });

  test('moving into another folder under a new name is refused when the source name is taken there', () async {
    await call('makeDirectory', {'location': 'granted:$id/dst'});
    await call('write', {'location': 'granted:$id/f', 'data': _bytes('src'), 'mode': 'create'});
    await call('write', {'location': 'granted:$id/dst/f', 'data': _bytes('other'), 'mode': 'create'});

    expectError(await call('move', {'from': 'granted:$id/f', 'to': 'granted:$id/dst/g'}), errAlreadyExists);
    expect(_text((await call('read', {'location': 'granted:$id/dst/f'}) as Map)['data']), 'other', reason: 'the other file is untouched');
  });

  test('a permission the system took away is permission_denied, and the grant stays listed', () async {
    saf.revoked = true;

    expectError(await call('list', {'location': 'granted:$id'}), errPermissionDenied);
    expect((await call('grants', {}) as Map)['grants'], hasLength(1));
  });

  test('revoke forgets the grant and leaves the files alone', () async {
    await call('write', {'location': 'granted:$id/keep', 'data': _bytes('x'), 'mode': 'create'});

    await call('revoke', {'id': id});

    expectError(await call('list', {'location': 'granted:$id'}), errNotFound);
    expect(saf.root.children.containsKey('keep'), isTrue);
  });

  test('a granted location is not reachable outside its tree', () async {
    expectError(await call('read', {'location': 'granted:$id/../x'}), errInvalidPath);
    expectError(await call('copy', {'from': 'granted:$id/a', 'to': 'app-cache:a'}), errCrossRoot);
  });
}

class _MemoryStore implements GrantStore {
  List<Grant> grants = [];

  @override
  Future<List<Grant>> load() async => List.of(grants);

  @override
  Future<void> save(List<Grant> next) async => grants = List.of(next);
}
