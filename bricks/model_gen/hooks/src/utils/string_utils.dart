class StringUtils {
  /// Converts string to camelCase
  /// Example: "user_name" -> "userName"
  static String toCamelCase(String input) {
    input = input.replaceAll(RegExp(r'^_+'), '');
    final parts = input.split(RegExp(r'[_\s]+'));

    if (parts.isEmpty) return input;

    return parts.first +
        parts
            .skip(1)
            .map((p) => p.isNotEmpty
            ? '${p[0].toUpperCase()}${p.substring(1)}'
            : '')
            .join();
  }

  /// Converts string to snake_case
  /// Example: "UserName" -> "user_name"
  static String toSnakeCase(String input) {
    return input
        .replaceAllMapped(
      RegExp(r'([A-Z])'),
          (m) => '_${m.group(0)!.toLowerCase()}',
    )
        .replaceFirst('_', '')
        .toLowerCase();
  }

  /// Converts string to PascalCase
  /// Example: "user_name" -> "UserName"
  static String toPascalCase(String input) {
    return input
        .split(RegExp(r'[_\s-]+'))
        .map((w) => w.isEmpty
        ? ''
        : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join();
  }

  /// Cleans field name from leading underscores
  /// Example: "_userName" -> "userName"
  static String cleanFieldName(String key) {
    if (key.startsWith('_')) {
      final clean = key.replaceFirst('_', '');
      return toCamelCase(clean);
    }
    return toCamelCase(key);
  }
}