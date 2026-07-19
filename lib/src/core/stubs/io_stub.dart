// Web stub for dart:io — only the parts used in school_repository.dart
// On web, file-based imports go through importStudentsFromBytes instead.
class File {
  final String path;
  File(this.path);
  Future<List<int>> readAsBytes() async => throw UnsupportedError(
      'dart:io File is not available on web. Use bytes-based API.');
  Future<String> readAsString() async => throw UnsupportedError(
      'dart:io File is not available on web.');
}
