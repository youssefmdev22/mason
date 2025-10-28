import 'dart:io';

import 'package:mason/mason.dart';

import '../utils/file_paths.dart';
import '../utils/string_utils.dart';

class RepositoryImplGenerator {
  final String featureName;
  final String type; // 'Remote' or 'Local'
  final List<String> imports;
  final List<Map<String, dynamic>> methods;

  RepositoryImplGenerator({
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
    final className = '${pascalName}RepositoryImpl';
    final filePaths = FilePaths(featureName);

    // Add imports
    for (final import in imports) {
      buffer.writeln(import);
    }
    buffer.writeln(filePaths.repositoryImplImport);

    buffer.writeln(filePaths.repositoryImplImport2.replaceAll("%name%",
        "${StringUtils.toSnakeCase(featureName)}_${StringUtils.toSnakeCase(type)}"));
    buffer.writeln("import 'package:injectable/injectable.dart';");
    buffer.writeln();

    // Add class
    buffer.writeln('@Injectable(as: ${pascalName}Repository)');
    buffer.writeln('class $className implements ${pascalName}Repository {');
    buffer.writeln('  final ${pascalName}${type}DataSource _dataSource;');
    buffer.writeln();
    buffer.writeln('  $className(this._dataSource);');
    buffer.writeln();

    // Add methods
    for (final method in methods) {
      // Fix type casting
      final paramsList = method['parameters'] as List;
      final params = paramsList.map((e) {
        final map = e as Map;
        return {
          'type': map['type'] as String,
          'name': map['name'] as String,
        };
      }).toList();
      final paramNames = params.map((p) => p['name']).join(', ');

      buffer.writeln('  @override');
      buffer.writeln(
          '  ${method['return_type']} ${method['name']}(${method['params_str']}) ${method['is_async'] ? 'async ' : ''}{');
      buffer.writeln(
          '    return ${method['is_async'] ? 'await ' : ''}_dataSource.${method['name']}($paramNames);');
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

    // Add new imports
    final existingImports = <String>[];
    final importRegex = RegExp("import\\s+['\"]([^'\"]+)['\"];");
    for (final match in importRegex.allMatches(content)) {
      existingImports.add(match.group(0)!);
    }

    final allImports = {...existingImports, ...imports}.toList()..sort();
    for (final import in allImports) {
      buffer.writeln(import);
    }

    // Preserve required imports
    if (!content.contains(filePaths.repositoryImplImport)) {
      buffer.writeln(filePaths.repositoryImplImport);
    }
    final dataSourceImport = filePaths.repositoryImplImport2.replaceAll(
        "%name%",
        "${StringUtils.toSnakeCase(featureName)}_${StringUtils.toSnakeCase(type)}");
    if (!content.contains(dataSourceImport)) {
      buffer.writeln(dataSourceImport);
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
      buffer.writeln('@Injectable(as: ${pascalName}Repository)');
    }

    // Find class start and preserve constructor
    final classRegex = RegExp(r'class \w+ implements \w+ \{[^}]*\}',
        multiLine: true, dotAll: true);
    final classMatch = classRegex.firstMatch(content);

    if (classMatch != null) {
      // Extract existing class structure
      final classContent = classMatch.group(0)!;
      final lines = classContent.split('\n');

      // Add class header, field, and constructor
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('@override') || lines[i].trim().startsWith('//'))
          break;
        buffer.writeln(lines[i]);
      }

      // Add new methods
      for (final method in methods) {
        final methodSignature = '${method['name']}(${method['params_str']})';
        if (!content.contains(methodSignature)) {
          // Fix type casting
          final paramsList = method['parameters'] as List;
          final params = paramsList.map((e) {
            final map = e as Map;
            return {
              'type': map['type'] as String,
              'name': map['name'] as String,
            };
          }).toList();
          final paramNames = params.map((p) => p['name']).join(', ');

          buffer.writeln('  @override');
          buffer.writeln(
              '  ${method['return_type']} ${method['name']}(${method['params_str']}) ${method['is_async'] ? 'async ' : ''}{');
          buffer.writeln(
              '    return ${method['is_async'] ? 'await ' : ''}_dataSource.${method['name']}($paramNames);');
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
