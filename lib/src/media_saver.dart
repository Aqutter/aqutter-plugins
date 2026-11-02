import 'dart:typed_data';

import 'package:gal/gal.dart';

import 'location.dart';

/// 把圖片放進系統相簿；測試可注入。
abstract class GalleryWriter {
  /// [name] 不含副檔名。權限被拒絕時拋出 [FileManagerException]（`permission_denied`）。
  Future<void> putImage(Uint8List bytes, String name);
}

/// 以 `gal` 實作：Android 10+ 走 MediaStore，iOS 走相簿「只新增」權限。
class GalGalleryWriter implements GalleryWriter {
  @override
  Future<void> putImage(Uint8List bytes, String name) async {
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        throw const FileManagerException(errPermissionDenied, '沒有存入相簿的權限');
      }
      await Gal.putImageBytes(bytes, name: name);
    }
    on GalException catch (error) {
      if (error.type == GalExceptionType.accessDenied) {
        throw const FileManagerException(errPermissionDenied, '沒有存入相簿的權限');
      }
      throw FileManagerException(errInvalidPath, '無法存入相簿：${error.type.message}');
    }
  }
}

/// 檔名：單一檔名，無路徑分隔、無控制字元、不是 `.`／`..`、≤ 255（契約 §2）。
String validateFileName(Object? value) {
  if (value is! String || value.isEmpty || value.length > 255) {
    throw const FileManagerException(errInvalidPath, 'name 必須是 1 到 255 字元的檔名');
  }
  if (value == '.' || value == '..' || value.contains('/') || value.contains('\\') || value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f)) {
    throw const FileManagerException(errInvalidPath, 'name 必須是單一檔名，不得含路徑分隔或控制字元');
  }
  return value;
}

const List<int> _pngSignature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

/// 圖片的實際格式（看位元組開頭）；不是 PNG 或 JPEG 回 null。
String? sniffImageMime(Uint8List bytes) {
  if (bytes.length >= _pngSignature.length && List.generate(_pngSignature.length, (i) => bytes[i]).toString() == _pngSignature.toString()) {
    return 'image/png';
  }
  if (bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) {
    return 'image/jpeg';
  }
  return null;
}

/// 驗證 `saveToGallery` 的參數並存入相簿。圖片只收 PNG 與 JPEG，位元組開頭必須與宣告的 `mimeType` 相符。
Future<Map<String, dynamic>> saveToGallery(Map<String, dynamic> payload, GalleryWriter writer) async {
  final name = validateFileName(payload['name']);
  final data = payload['data'];
  if (data is! Uint8List) {
    throw const FileManagerException(errInvalidPath, 'data 必須是二進位');
  }
  if (data.length > maxContentBytes) {
    throw FileManagerException(errTooLarge, 'data 不得超過 $maxContentBytes 位元組');
  }
  final declared = payload['mimeType'];
  if (declared != 'image/png' && declared != 'image/jpeg') {
    throw const FileManagerException(errInvalidPath, 'mimeType 必須是 image/png 或 image/jpeg');
  }
  if (sniffImageMime(data) != declared) {
    throw const FileManagerException(errInvalidPath, '圖片內容與宣告的 mimeType 不符');
  }
  final dot = name.lastIndexOf('.');
  await writer.putImage(data, dot > 0 ? name.substring(0, dot) : name);
  return {'status': 'saved'};
}
