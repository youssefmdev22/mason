class StringUtils {
  /// Converts string to camelCase
  /// Example: "user_name" -> "userName"
  ///          "user name" -> "userName"
  static String toCamelCase(String input) {
    input = input.trim().replaceAll(RegExp(r'^_+'), '');
    final parts = input.split(RegExp(r'[_\s-]+'));

    if (parts.isEmpty) return input;

    return parts.first.toLowerCase() +
        parts
            .skip(1)
            .map((p) => p.isNotEmpty
            ? '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}'
            : '')
            .join();
  }

  /// Converts string to snake_case
  /// Example: "UserName" -> "user_name"
  ///          "user name" -> "user_name"
  ///          "user-Name" -> "user_name"
  static String toSnakeCase(String input) {
    return input
        .trim()
        .replaceAllMapped(
      RegExp(r'([A-Z])'),
          (m) => '_${m.group(0)!.toLowerCase()}',
    )
        .replaceAll(RegExp(r'[\s\-]+'), '_')
        .replaceFirst(RegExp(r'^_+'), '')
        .toLowerCase();
  }

  /// Converts string to PascalCase
  /// Example: "user_name" -> "UserName"
  ///          "user name" -> "UserName"
  ///          "user-name" -> "UserName"
  static String toPascalCase(String input) {
    return input
        .trim()
        .split(RegExp(r'[_\s-]+'))
        .map((w) => w.isEmpty
        ? ''
        : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join();
  }

  /// Cleans field name from leading underscores
  /// Example: "_userName" -> "userName"
  static String cleanFieldName(String key) {
    key = key.trim();
    if (key.startsWith('_')) {
      key = key.replaceFirst(RegExp(r'^_+'), '');
    }
    return toCamelCase(key);
  }
}