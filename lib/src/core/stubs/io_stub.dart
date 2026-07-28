// Web stub for dart:io — matches the real dart:io File API used in this app.
// On web, file-based imports go through importStudentsFromBytes instead.
import 'dart:typed_data';

class File {
  final String path;
  File(this.path);

  Future<Uint8List> readAsBytes() async => throw UnsupportedError(
      'dart:io File is not available on web. Use bytes-based API.');

  Future<String> readAsString() async => throw UnsupportedError(
      'dart:io File is not available on web.');

  Future<File> writeAsBytes(List<int> bytes, {bool flush = false}) async =>
      throw UnsupportedError(
          'dart:io File is not available on web. Use bytes-based API.');

  Future<File> writeAsString(String contents,
          {bool flush = false}) async =>
      throw UnsupportedError(
          'dart:io File is not available on web.');
}
