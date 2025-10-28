import 'dart:io';

import 'package:mason/mason.dart';

import '../utils/string_utils.dart';

class DataSourceGenerator {
  final String featureName;
  final String type; // 'Remote' or 'Local'
  final List<String> imports;
  final List<Map<String, dynamic>> methods;

  DataSourceGenerator({
    required this.featureName,
    required this.type,
    required this.imports,
    required this.methods,
  });

  Future<void> generate(String path, Logger logger) async {
    final file = File(path);
    final exists = file.existsSync();

    if (!exists) {
      await _createNewFile(file, logger);
    } else {
      await _updateExistingFile(file, logger);
    }
  }

  Future<void> _createNewFile(File file, Logger logger) async {
    final buffer = StringBuffer();
    final pascalName = StringUtils.toPascalCase(featureName);
    final className = '$pascalName${type}DataSource';

    // Add imports
    for (final import in imports) {
      buffer.writeln(import);
    }
    buffer.writeln();

    // Add class
    buffer.writeln('abstract interface class $className {');

    // Add methods
    for (final method in methods) {
      buffer.writeln(
          '  ${method['return_type']} ${method['name']}(${method['params_str']});');
      buffer.writeln();
    }

    buffer.writeln('}');

    await file.create(recursive: true);
    await file.writeAsString(buffer.toString());
    logger.info('Created: ${file.path}');
  }

  Future<void> _updateExistingFile(File file, Logger logger) async {
    final content = await file.readAsString();
    final buffer = StringBuffer();

    // Merge imports
    final existingImports = <String>[];
    final importRegex = RegExp("import\\s+['\"]([^'\"]+)['\"];");
    for (final match in importRegex.allMatches(content)) {
      existingImports.add(match.group(0)!);
    }

    final allImports = {...existingImports, ...imports}.toList()..sort();
    for (final import in allImports) {
      buffer.writeln(import);
    }
    buffer.writeln();

    // Find class body
    final classStartRegex =
        RegExp(r'abstract\s+(?:interface\s+)?class\s+\w+\s*\{');
    final classStart = classStartRegex.firstMatch(content);

    if (classStart != null) {
      buffer.writeln(content.substring(classStart.start, classStart.end));
      buffer.writeln();

      // Add new methods
      for (final method in methods) {
        final methodSignature = '${method['name']}(${method['params_str']})';
        if (!content.contains(methodSignature)) {
          buffer.writeln(
              '  ${method['return_type']} ${method['name']}(${method['params_str']});');
          buffer.writeln();
        }
      }

      // Preserve existing methods
      final existingMethodsRegex = RegExp(
        r'  [\w<>]+\s+\w+\([^)]*\);',
        multiLine: true,
      );
      for (final match in existingMethodsRegex.allMatches(content)) {
        final existingMethod = match.group(0)!;
        if (!buffer.toString().contains(existingMethod)) {
          buffer.writeln(existingMethod);
          buffer.writeln();
        }
      }
    }

    buffer.writeln('}');

    await file.writeAsString(buffer.toString());
    logger.info('Updated: ${file.path}');
  }
}
