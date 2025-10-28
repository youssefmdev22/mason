import 'dart:convert';
import 'dart:io';
import 'package:mason/mason.dart';

class JsonParser {
  /// Reads and parses JSON from file
  static Map<String, dynamic>? parseFromFile(String filePath, Logger logger) {
    final file = File(filePath);

    if (!file.existsSync()) {
      logger.err('Missing $filePath file in root directory.');
      return null;
    }

    try {
      final content = file.readAsStringSync();
      final jsonData = json.decode(content) as Map<String, dynamic>;

      if (jsonData.isEmpty) {
        logger.warn('JSON file is empty');
        return null;
      }

      logger.info('JSON parsed successfully');
      return jsonData;
    } catch (e) {
      logger.err('Invalid JSON format: $e');
      return null;
    }
  }

  /// Validates JSON structure
  static bool validate(Map<String, dynamic> json, Logger logger) {
    if (json.isEmpty) {
      logger.err('JSON cannot be empty');
      return false;
    }

    // Add more validation rules if needed
    return true;
  }
}