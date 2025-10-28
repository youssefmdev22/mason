import 'string_utils.dart';

class TypeResolver {
  /// Resolves Dart type from JSON value
  static String resolveType(
      dynamic value,
      String key, {
        required bool isModel,
      }) {
    if (value is bool) return 'bool';
    if (value is int || value is double) return 'num';
    if (value is String) return 'String';

    if (value is List) {
      return _resolveListType(value, key, isModel: isModel);
    }

    if (value is Map) {
      final suffix = isModel ? 'DTO' : 'Entity';
      return '${StringUtils.toPascalCase(key)}$suffix';
    }

    return 'dynamic';
  }

  static String _resolveListType(
      List value,
      String key, {
        required bool isModel,
      }) {
    if (value.isEmpty) return 'List<dynamic>';

    final first = value.first;
    final suffix = isModel ? 'DTO' : 'Entity';

    if (first is Map) {
      return 'List<${StringUtils.toPascalCase(key)}$suffix>';
    }
    if (first is bool) return 'List<bool>';
    if (first is int || first is double) return 'List<num>';
    if (first is String) return 'List<String>';

    return 'List<dynamic>';
  }

  /// Checks if value is a nested object
  static bool isNestedObject(dynamic value) {
    return value is Map<String, dynamic>;
  }

  /// Checks if value is a list of objects
  static bool isListOfObjects(dynamic value) {
    return value is List && value.isNotEmpty && value.first is Map;
  }

  /// Checks if field needs mapping (nested object or list of objects)
  static bool needsMapping(dynamic value) {
    return isNestedObject(value) || isListOfObjects(value);
  }
}