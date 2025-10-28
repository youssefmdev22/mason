import 'dart:io';

import 'package:mason/mason.dart';

import '../utils/file_paths.dart';
import '../utils/string_utils.dart';

class DataSourceImplGenerator {
  final String featureName;
  final String type; // 'Remote' or 'Local'
  final List<String> imports;
  final List<Map<String, String>> dependencies;
  final List<Map<String, dynamic>> methods;

  DataSourceImplGenerator({
    required this.featureName,
    required this.type,
    required this.imports,
    required this.dependencies,
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
    final className = '$pascalName${type}DataSourceImpl';
    final filePaths = FilePaths(featureName);

    // Add imports
    for (final import in imports) {
      buffer.writeln(import);
    }
    buffer.writeln(filePaths.dataSourceImplImport.replaceAll(
        "%name%", "${StringUtils.toSnakeCase(featureName)}_${StringUtils.toSnakeCase(type)}"));
    buffer.writeln("import 'package:injectable/injectable.dart';");
    buffer.writeln();

    // Add class
    buffer.writeln('@Injectable(as: ${pascalName}${type}DataSource)');
    buffer.writeln('class $className implements ${pascalName}${type}DataSource {');

    // Add dependencies
    if (dependencies.isNotEmpty) {
      for (final dep in dependencies) {
        buffer.writeln('  final ${dep['type']} ${dep['name']};');
      }
      buffer.writeln();

      // Add constructor
      buffer.write('  $className(');
      buffer.write(dependencies.map((d) => 'this.${d['name']}').join(', '));
      buffer.writeln(');');
      buffer.writeln();
    }

    // Add methods
    for (final method in methods) {
      buffer.writeln('  @override');
      buffer.writeln(
          '  ${method['return_type']} ${method['name']}(${method['params_str']}) ${method['is_async'] ? 'async ' : ''}{');
      buffer.writeln('    ${method['body']}');
      buffer.writeln('  }');
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
    final filePaths = FilePaths(featureName);

    // Merge imports
    final existingImports = <String>[];
    final importRegex = RegExp("import\\s+['\"]([^'\"]+)['\"]");
    for (final match in importRegex.allMatches(content)) {
      existingImports.add("${match.group(0)!};");
    }

    final allImports = {...existingImports, ...imports}.toList()..sort();
    for (final import in allImports) {
      buffer.writeln(import);
    }

    final importDataSource = filePaths.dataSourceImplImport.replaceAll(
        "%name%", "${StringUtils.toSnakeCase(featureName)}_${StringUtils.toSnakeCase(type)}");
    if (!content.contains(importDataSource)) {
      buffer.writeln(importDataSource);
    }
    if (!content.contains("import 'package:injectable/injectable.dart';")) {
      buffer.writeln("import 'package:injectable/injectable.dart';");
    }
    buffer.writeln();

    // Preserve @Injectable annotation
    final injectableRegex = RegExp(r'@Injectable\([^)]*\)');
    final injectableMatch = injectableRegex.firstMatch(content);
    if (injectableMatch != null) {
      buffer.writeln(injectableMatch.group(0)!);
    } else {
      // Add it if not found
      final pascalName = StringUtils.toPascalCase(featureName);
      buffer.writeln('@Injectable(as: ${pascalName}${type}DataSource)');
    }

    // Find class and constructor
    final classRegex = RegExp(r'class (\w+) implements \w+ \{');
    final classMatch = classRegex.firstMatch(content);

    if (classMatch != null) {
      final className = classMatch.group(1)!;
      buffer.writeln(
          'class $className implements ${StringUtils.toPascalCase(featureName)}${type}DataSource {');

      // MERGE dependencies - keep existing + add new ones
      final existingDepsMap = <String, Map<String, String>>{};
      final existingDepsRegex = RegExp(r'  final (\S+) (_?\w+);');

      // Collect existing dependencies
      for (final match in existingDepsRegex.allMatches(content)) {
        final type = match.group(1)!;
        final name = match.group(2)!;
        existingDepsMap[name] = {'type': type, 'name': name};
      }

      // Add new dependencies (don't override existing ones)
      for (final dep in dependencies) {
        final depName = dep['name']!;
        if (!existingDepsMap.containsKey(depName)) {
          existingDepsMap[depName] = dep;
        }
      }

      // Write all dependencies
      final allDeps = existingDepsMap.values.toList();
      if (allDeps.isNotEmpty) {
        for (final dep in allDeps) {
          buffer.writeln('  final ${dep['type']} ${dep['name']};');
        }
        buffer.writeln();

        // Write constructor with all dependencies
        buffer.write('  $className(');
        buffer.write(allDeps.map((d) => 'this.${d['name']}').join(', '));
        buffer.writeln(');');
        buffer.writeln();
      }

      // Add new methods
      for (final method in methods) {
        final methodSignature = '${method['name']}(${method['params_str']})';
        if (!content.contains(methodSignature)) {
          buffer.writeln('  @override');
          buffer.writeln(
              '  ${method['return_type']} ${method['name']}(${method['params_str']}) ${method['is_async'] ? 'async ' : ''}{');
          buffer.writeln('    ${method['body']}');
          buffer.writeln('  }');
          buffer.writeln();
        }
      }

      // Preserve existing methods
      final existingMethodsRegex = RegExp(
        r'  @override\s+[\w<>]+\s+\w+\([^)]*\)[^{]*\{[^}]*\}',
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
