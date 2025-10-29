import 'dart:io';
import 'package:mason/mason.dart';
import '../models/generation_config.dart';
import '../utils/string_utils.dart';
import '../utils/type_resolver.dart';
import '../utils/file_utils.dart';

class EntityGenerator {
  static void generate({
    required GenerationConfig config,
    required Map<String, dynamic> jsonData,
    required List<MapEntry<String, Map<String, dynamic>>> nestedClasses,
    required Logger logger,
  }) {
    final buffer = StringBuffer();

    // Generate imports
    _generateImports(buffer, config, nestedClasses);

    // Generate main entity
    _generateMainEntity(
      buffer,
      config: config,
      jsonData: jsonData,
      nestedClasses: nestedClasses,
    );

    // Generate nested entities
    for (final nested in nestedClasses) {
      _generateNestedEntity(
        buffer,
        config: config,
        nestedName: nested.key,
        jsonData: nested.value,
      );
    }

    // Write file
    String filePath = _getFilePath(config);
    File file = File(filePath);
    file.parent.createSync(recursive: true);

    /*if (file.existsSync()) {
      logger.warn('File already exists: $filePath');
      final response = logger.confirm('Do you want to overwrite it?');

      if (!response) {
        logger.info('Skipped generating entity (file already exists).');
        return;
      }
    }*/

    if (file.existsSync()) {
      logger.warn('File already exists: $filePath');

      final choice = logger.chooseOne(
        'File already exists. What do you want to do?',
        choices: ['Skip', 'Overwrite', 'Rename'],
        defaultValue: 'Skip',
      );

      if (choice == 'Skip') {
        logger.info('Skipped generating entity (file already exists).');
        return;
      } else if (choice == 'Rename') {
        final newName = logger.prompt('Enter a new file name (without extension):');
        final dir = file.parent.path;
        final ext = file.path.split('.').last;
        filePath = '$dir/$newName.$ext';
        file = File(filePath);
      }
    }

    file.writeAsStringSync(buffer.toString());

    FileUtils.formatFile(file);
    logger.success('Entity generated: $filePath');
  }

  static void _generateImports(
      StringBuffer buffer,
      GenerationConfig config,
      List<MapEntry<String, Map<String, dynamic>>> nestedClasses,
      ) {
    // Model import (if Request type with mapper)
    if (config.mapperOption != MapperOption.extension && !config.isResponseType) {
      final modelPath = _getRelativeModelPath(config);
      final modelImport = modelPath.substring(
        modelPath.indexOf('/') + 1,
      );
      buffer.writeln("import 'package:${config.packageName}/$modelImport';");
    }

    // AutoMappr (if needed)
    if (config.mapperOption == MapperOption.autoMap && !config.isResponseType) {
      buffer.writeln("import 'package:auto_mappr_annotation/auto_mappr_annotation.dart';");
      final fileName = _getFileName(config);
      buffer.writeln("import '$fileName.auto_mappr.dart';");
    }

    if (buffer.isNotEmpty) buffer.writeln();
  }

  static void _generateMainEntity(
      StringBuffer buffer, {
        required GenerationConfig config,
        required Map<String, dynamic> jsonData,
        required List<MapEntry<String, Map<String, dynamic>>> nestedClasses,
      }) {
    final className = _getClassName(config);
    final modelName = _getModelClassName(config);

    // AutoMappr annotation
    if (config.mapperOption == MapperOption.autoMap && !config.isResponseType) {
      buffer.writeln('@AutoMappr([');
      buffer.writeln('  MapType<$className, $modelName>(),');

      for (final nested in nestedClasses) {
        final nestedEntity = '${nested.key}Entity';
        final nestedModel = '${nested.key}DTO';
        buffer.writeln('  MapType<$nestedEntity, $nestedModel>(),');
      }

      buffer.writeln('])');
    }

    buffer.writeln('class $className {');

    // Fields
    jsonData.forEach((key, value) {
      final fieldName = StringUtils.toCamelCase(key);
      final fieldType = TypeResolver.resolveType(value, key, isModel: false);
      buffer.writeln('  final $fieldType? $fieldName;');
    });

    buffer.writeln();

    // Constructor
    buffer.writeln('  $className({');
    jsonData.keys.forEach((key) {
      buffer.writeln('    required this.${StringUtils.toCamelCase(key)},');
    });
    buffer.writeln('  });');

    // toRequest function (if Function mapper and Request type)
    if (config.mapperOption == MapperOption.function && !config.isResponseType) {
      buffer.writeln();
      buffer.writeln('  $modelName toRequest() {');
      buffer.writeln('    return $modelName(');
      jsonData.forEach((key, value) {
        final fieldName = StringUtils.toCamelCase(key);
        final mapping = _generateFieldMapping(value, fieldName);
        buffer.writeln('      $fieldName: $mapping,');
      });
      buffer.writeln('    );');
      buffer.writeln('  }');
    }

    // AutoMappr variable (if needed)
    if (config.mapperOption == MapperOption.autoMap && !config.isResponseType) {
      buffer.writeln();
      buffer.writeln('static const mapper = \$$className();');
    }

    buffer.writeln('}');
    buffer.writeln();
  }

  static void _generateNestedEntity(
      StringBuffer buffer, {
        required GenerationConfig config,
        required String nestedName,
        required Map<String, dynamic> jsonData,
      }) {
    final className = '${nestedName}Entity';
    final modelName = '${nestedName}DTO';

    buffer.writeln('class $className {');

    // Fields
    jsonData.forEach((key, value) {
      final fieldName = StringUtils.toCamelCase(key);
      final fieldType = TypeResolver.resolveType(value, key, isModel: false);
      buffer.writeln('  final $fieldType? $fieldName;');
    });

    buffer.writeln();

    // Constructor
    buffer.writeln('  $className({');
    jsonData.keys.forEach((key) {
      buffer.writeln('    required this.${StringUtils.toCamelCase(key)},');
    });
    buffer.writeln('  });');

    // toRequest (if needed)
    if (config.mapperOption == MapperOption.function && !config.isResponseType) {
      buffer.writeln();
      buffer.writeln('  $modelName toRequest() {');
      buffer.writeln('    return $modelName(');
      jsonData.forEach((key, value) {
        final fieldName = StringUtils.toCamelCase(key);
        final mapping = _generateFieldMapping(value, fieldName);
        buffer.writeln('      $fieldName: $mapping,');
      });
      buffer.writeln('    );');
      buffer.writeln('  }');
    }

    buffer.writeln('}');
    buffer.writeln();
  }

  static String _generateFieldMapping(dynamic value, String fieldName) {
    if (TypeResolver.isNestedObject(value)) {
      return '$fieldName?.toRequest()';
    } else if (TypeResolver.isListOfObjects(value)) {
      return '$fieldName?.map((item) => item.toRequest()).toList()';
    }
    return fieldName;
  }

  static String _getFilePath(GenerationConfig config) {
    final fileName = _getFileName(config);
    return '${config.entityPath}/$fileName.dart';
  }

  static String _getFileName(GenerationConfig config) {
    final name = StringUtils.toSnakeCase(config.entityName);
    final suffix = config.isResponseType ? '' : '_request';
    return '${name}${suffix}_entity';
  }

  static String _getClassName(GenerationConfig config) {
    return StringUtils.toPascalCase(_getFileName(config));
  }

  static String _getModelClassName(GenerationConfig config) {
    final name = StringUtils.toSnakeCase(config.modelName);
    final suffix = config.isResponseType ? '_response' : '_request';
    return StringUtils.toPascalCase('$name$suffix');
  }

  static String _getRelativeModelPath(GenerationConfig config) {
    final dir = config.isResponseType ? 'responses' : 'requests';
    final name = StringUtils.toSnakeCase(config.modelName);
    final suffix = config.isResponseType ? '_response' : '_request';
    return '${config.modelPath}/$dir/$name$suffix.dart';
  }
}