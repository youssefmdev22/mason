/// Represents field information for code generation
class FieldInfo {
  final String originalName;
  final String dartName;
  final String type;
  final bool isNullable;
  final bool isNested;
  final bool isList;

  FieldInfo({
    required this.originalName,
    required this.dartName,
    required this.type,
    this.isNullable = false,
    this.isNested = false,
    this.isList = false,
  });

  /// Creates FieldInfo from JSON key-value pair
  factory FieldInfo.fromJson(String key, dynamic value, {required bool isModel}) {
    // Implementation can be added later if needed
    throw UnimplementedError('Use TypeResolver directly for now');
  }
}