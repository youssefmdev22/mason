class StringUtils {

  static String toCamelCase(String input) {
    input = input.trim().replaceAll(RegExp(r'^[_\s]+'), '');

    if (!input.contains(RegExp(r'[_\s-]'))) {
      return input.isEmpty
          ? input
          : input[0].toLowerCase() + input.substring(1);
    }

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

  static String toSnakeCase(String input) {
    input = input.trim();
    input = input.replaceAll(RegExp(r'[\s-]+'), '_');
    input = input.replaceAll(RegExp(r'^[_\s]+'), '');
    final result = input
        .replaceAllMapped(
        RegExp(r'(?<=[a-z0-9])([A-Z])'), (m) => '_${m.group(1)}')
        .replaceAllMapped(RegExp(r'([A-Z])([A-Z][a-z])'),
            (m) => '${m.group(1)}_${m.group(2)}')
        .toLowerCase();
    return result.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static String toPascalCase(String input) {
    if (input.isEmpty) return input;
    input = input.trim();
    final isPascal = RegExp(r'^[A-Z][a-z0-9]+(?:[A-Z][a-z0-9]+)*$');
    if (isPascal.hasMatch(input)) return input;
    input = input
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final parts = input.split(RegExp(r'[_]+'));
    return parts
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
        .join();
  }

}
