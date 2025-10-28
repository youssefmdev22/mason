import 'dart:io';

class FileUtils {
  /// Formats Dart file using dart format
  static void formatFile(File file) {
    try {
      final result = Process.runSync(
        'dart',
        ['format', file.path],
      );

      if (result.exitCode != 0) {
        print('Warning: Failed to format ${file.path}');
      }
    } catch (e) {
      print('Warning: dart format not available: $e');
    }
  }

  /// Creates directory if it doesn't exist
  static void ensureDirectory(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  /// Gets relative path from package root
  static String getRelativePath(String fullPath) {
    if (fullPath.contains('/lib/')) {
      return fullPath.substring(fullPath.indexOf('/lib/') + 1);
    }
    return fullPath;
  }
}