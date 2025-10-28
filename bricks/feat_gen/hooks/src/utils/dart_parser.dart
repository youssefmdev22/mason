class DartParser {
  final String content;

  DartParser(this.content);

  /// Extract all imports from dart_gen.dart
  List<String> extractImports() {
    final importRegex = RegExp("import\\s+['\"]([^'\"]+)['\"]");
    return importRegex
        .allMatches(content)
        .map((m) => "${m.group(0)!};")
        .toList();
  }

  /// Extract constructor dependencies from dart_gen.dart
  List<Map<String, String>> extractDependencies() {
    final dependencies = <Map<String, String>>[];

    // Find constructor - supports both positional and named parameters
    // Matches: DartGen(this._x) OR DartGen({required this.x, this.y})
    final constructorRegex = RegExp(
      r'DartGen\s*\(\s*\{?([^)]+)\}?\s*\);',
      multiLine: true,
    );
    final constructorMatch = constructorRegex.firstMatch(content);

    if (constructorMatch == null) return dependencies;

    final constructorParams = constructorMatch.group(1)!;

    // Extract field names from constructor parameters
    // Matches: this._field OR required this.field
    final paramFieldRegex = RegExp(r'this\.(_?\w+)');
    final fieldNames = <String>[];

    for (final match in paramFieldRegex.allMatches(constructorParams)) {
      fieldNames.add(match.group(1)!);
    }

    // Now find the field declarations with their types
    // Matches: final Type _field; OR final Type field;
    for (final fieldName in fieldNames) {
      final fieldRegex = RegExp(
        r'final\s+(\S+)\s+' + RegExp.escape(fieldName) + r'\s*;',
        multiLine: true,
      );
      final fieldMatch = fieldRegex.firstMatch(content);

      if (fieldMatch != null) {
        final type = fieldMatch.group(1)!;
        dependencies.add({
          'type': type,
          'name': fieldName.startsWith('_') ? fieldName : fieldName,
        });
      }
    }

    return dependencies;
  }

  /// Extract all methods from dart_gen.dart
  List<Map<String, dynamic>> extractMethods() {
    final methods = <Map<String, dynamic>>[];

    // Updated regex to support:
    // - Custom types with generics: ApiSuccessResult<String>
    // - Nested generics: Future<ApiSuccessResult<String>>
    // - Simple types: void, String, etc.
    final methodRegex = RegExp(
      r'(\w+(?:<[^{]+>)?)\s+(\w+)\s*\(([^)]*)\)\s*(async)?\s*\{',
      multiLine: true,
    );

    for (final match in methodRegex.allMatches(content)) {
      final methodName = match.group(2)!;

      // Skip constructor
      if (methodName == 'DartGen') continue;

      final returnType = match.group(1)!;
      final paramsStr = match.group(3)!;
      final isAsync = match.group(4) != null;

      // Parse parameters
      final params = _parseParameters(paramsStr);

      // Extract method body
      final body = _extractMethodBody(match.end);

      methods.add({
        'name': methodName,
        'return_type': returnType,
        'is_async': isAsync,
        'parameters': params,
        'params_str': paramsStr,
        'body': body,
      });
    }

    return methods;
  }

  /// Parse method parameters - supports both positional and named
  List<Map<String, String>> _parseParameters(String paramsStr) {
    final params = <Map<String, String>>[];

    if (paramsStr.trim().isEmpty) return params;

    // Remove curly braces for named parameters
    final cleanParams = paramsStr
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('required', '')
        .trim();

    final paramsList = cleanParams.split(',');
    for (final param in paramsList) {
      final trimmed = param.trim();
      if (trimmed.isEmpty) continue;

      // Match: Type name or Type? name
      final paramRegex = RegExp(r'(\S+\??)\s+(\w+)');
      final match = paramRegex.firstMatch(trimmed);

      if (match != null) {
        params.add({
          'type': match.group(1)!,
          'name': match.group(2)!,
        });
      }
    }

    return params;
  }

  /// Extract method body by matching braces
  String _extractMethodBody(int methodStart) {
    int braceCount = 1;
    int bodyEnd = methodStart;

    for (int i = methodStart; i < content.length && braceCount > 0; i++) {
      if (content[i] == '{') braceCount++;
      if (content[i] == '}') braceCount--;
      bodyEnd = i;
    }

    return content.substring(methodStart, bodyEnd).trim();
  }
}