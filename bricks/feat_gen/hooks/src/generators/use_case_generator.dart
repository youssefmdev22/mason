import 'dart:io';

import 'package:mason/mason.dart';

import '../utils/file_paths.dart';
import '../utils/string_utils.dart';

class UseCaseGenerator {
  final String featureName;
  final List<String> imports;
  final List<Map<String, dynamic>> methods;
  final Map<String, String> useCaseNames;

  UseCaseGenerator({
    required this.featureName,
    required this.imports,
    required this.methods,
    required this.useCaseNames,
  });

  /// Generate separate use case file for each method
  Future<List<String>> generate(Logger logger) async {
    final generatedFiles = <String>[];

    for (final method in methods) {
      final methodName = method['name'] as String;
      final useCaseName = useCaseNames[methodName] ??
          '${StringUtils.toPascalCase(methodName)}UseCase';
      final fileName =
          StringUtils.toSnakeCase(useCaseName.replaceAll('UseCase', ''));
      final filePath = FilePaths.useCaseFile(fileName);

      await _generateUseCaseFile(
        filePath: filePath,
        useCaseName: useCaseName,
        method: method,
        logger: logger,
      );

      generatedFiles.add(filePath);
    }

    return generatedFiles;
  }

  Future<void> _generateUseCaseFile({
    required String filePath,
    required String useCaseName,
    required Map<String, dynamic> method,
    required Logger logger,
  }) async {
    final file = File(filePath);
    final exists = file.existsSync();

    if (!exists) {
      await _createNewUseCase(file, useCaseName, method, logger);
    } else {
      await _updateExistingUseCase(file, useCaseName, method, logger);
    }
  }

  Future<void> _createNewUseCase(
    File file,
    String useCaseName,
    Map<String, dynamic> method,
    Logger logger,
  ) async {
    final buffer = StringBuffer();
    final pascalName = StringUtils.toPascalCase(featureName);
    final filePaths = FilePaths(featureName);

    // Add imports
    for (final import in imports) {
      buffer.writeln(import);
    }
    buffer
        .writeln(filePaths.useCaseImport);
    buffer.writeln("import 'package:injectable/injectable.dart';");
    buffer.writeln();

    // Add class
    buffer.writeln('@injectable');
    buffer.writeln('class $useCaseName {');
    buffer.writeln('  final ${pascalName}Repository _repository;');
    buffer.writeln();
    buffer.writeln('  $useCaseName(this._repository);');
    buffer.writeln();

    // Add call method - Fix type casting here
    final paramsList = method['parameters'] as List;
    final params = paramsList.map((e) {
      final map = e as Map;
      return {
        'type': map['type'] as String,
        'name': map['name'] as String,
      };
    }).toList();
    final paramNames = params.map((p) => p['name']).join(', ');

    buffer.writeln(
        '  ${method['return_type']} call(${method['params_str']}) ${method['is_async'] ? 'async ' : ''}{');
    buffer.writeln(
        '    return ${method['is_async'] ? 'await ' : ''}_repository.${method['name']}($paramNames);');
    buffer.writeln('  }');
    buffer.writeln('}');

    await file.create(recursive: true);
    await file.writeAsString(buffer.toString());
    logger.info('Created: ${file.path}');
  }

  Future<void> _updateExistingUseCase(
    File file,
    String useCaseName,
    Map<String, dynamic> method,
    Logger logger,
  ) async {
    final content = await file.readAsString();

    // If call method already exists, skip
    if (content.contains('call(${method['params_str']})')) {
      logger.info('Skipped (already exists): ${file.path}');
      return;
    }

    // Otherwise, update the call method
    await _createNewUseCase(file, useCaseName, method, logger);
  }
}
