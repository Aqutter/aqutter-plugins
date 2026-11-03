import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';

import 'location.dart';

/// 使用者選到的一個檔案（一次性，不持久保存）。
class ChosenFile {
  const ChosenFile({required this.name, required this.path});

  final String name;
  final String path;
}

/// 開啟系統的檔案選擇器；測試可注入。取消回空清單。
abstract class FileChooser {
  Future<List<ChosenFile>> choose({required bool multiple, List<String>? extensions, String? title});
}

/// 以 `file_picker` 實作：桌面選到的是原路徑，Android 與 iOS 是 `file_picker` 複製進 App 快取的檔案。
class FilePickerFileChooser implements FileChooser {
  @override
  Future<List<ChosenFile>> choose({required bool multiple, List<String>? extensions, String? title}) async {
    final type = extensions == null ? FileType.any : FileType.custom;
    final List<PlatformFile> files;
    if (multiple) {
      files = await FilePicker.pickFiles(dialogTitle: title, type: type, allowedExtensions: extensions);
    }
    else {
      files = [await FilePicker.pickFile(dialogTitle: title, type: type, allowedExtensions: extensions)].whereType<PlatformFile>().toList();
    }
    return [
      for (final file in files)
        if (file.path != null) ChosenFile(name: file.name, path: file.path!),
    ];
  }
}

/// 一次性選取的登記表：編號只存在記憶體裡，App 重啟後失效，也不會出現在授權清單。
class PickedRegistry {
  PickedRegistry({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  final Map<String, String> _paths = {};

  String _newId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(12, (_) => alphabet[_random.nextInt(alphabet.length)]).join();
  }

  /// 登記一個實際路徑；同一個路徑重複登記沿用原來的編號。
  String register(String path) {
    for (final entry in _paths.entries) {
      if (entry.value == path) {
        return entry.key;
      }
    }
    final id = _newId();
    _paths[id] = path;
    return id;
  }

  /// 編號對應的實際路徑；編號不存在或檔案已不在回 `not_found`。
  String resolve(String id) {
    final path = _paths[id];
    if (path == null || FileSystemEntity.typeSync(path) != FileSystemEntityType.file) {
      throw FileManagerException(errNotFound, '沒有選取「$id」，或檔案已不存在；請重新選取');
    }
    return path;
  }
}
