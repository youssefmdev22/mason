import 'dart:io';
import 'package:mason/mason.dart';
import '../models/generation_config.dart';
import '../utils/string_utils.dart';
import '../utils/type_resolver.dart';
import '../utils/file_utils.dart';

class ModelGenerationResult {
  final String filePath;
  final List<MapEntry<String, Map<String, dynamic>>> nestedClasses;

  ModelGenerationResult({
    required this.filePath,
    required this.nestedClasses,
  });
}

class ModelGenerator {
  static ModelGenerationResult generate({
    required GenerationConfig config,
    required Map<String, dynamic> jsonData,
    required Logger logger,
  }) {
    final buffer = StringBuffer();
    final nestedClasses = <MapEntry<String, Map<String, dynamic>>>[];

    // Collect nested classes first
    _collectNestedClasses(jsonData, nestedClasses);

    // Generate imports
    _generateImports(buffer, config, nestedClasses);

    // Generate main class
    _generateMainClass(
      buffer,
      config: config,
      jsonData: jsonData,
      nestedClasses: nestedClasses,
    );

    // Generate nested classes
    for (final nested in nestedClasses) {
      _generateNestedClass(
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
        logger.info('Skipped generating model (file already exists).');
        return ModelGenerationResult(
          filePath: filePath,
          nestedClasses: nestedClasses,
        );
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
        logger.info('Skipped generating model (file already exists).');
        return ModelGenerationResult(
          filePath: filePath,
          nestedClasses: nestedClasses,
        );
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
    logger.success('Model generated: $filePath');

    return ModelGenerationResult(
      filePath: filePath,
      nestedClasses: nestedClasses,
    );
  }

  static void _generateImports(
      StringBuffer buffer,
      GenerationConfig config,
      List<MapEntry<String, Map<String, dynamic>>> nestedClasses,
      ) {
    // Entity import (if needed)
    if (config.createEntity &&
        config.mapperOption != MapperOption.extension &&
        config.isResponseType) {
      final entityPath = _getRelativeEntityPath(config);
      final entityImport = entityPath.substring(
        entityPath.indexOf('/') + 1,
      );
      buffer.writeln("import 'package:${config.packageName}/$entityImport';");
    }

    // json_annotation
    buffer.writeln("import 'package:json_annotation/json_annotation.dart';");

    // AutoMappr (if needed)
    if (config.createEntity &&
        config.mapperOption == MapperOption.autoMap &&
        config.isResponseType) {
      buffer.writeln("import 'package:auto_mappr_annotation/auto_mappr_annotation.dart';");
      final fileName = _getFileName(config);
      buffer.writeln("import '$fileName.auto_mappr.dart';");
    }

    buffer.writeln();
    buffer.writeln("part '${_getFileName(config)}.g.dart';");
    buffer.writeln();
  }

  static void _generateMainClass(
      StringBuffer buffer, {
        required GenerationConfig config,
        required Map<String, dynamic> jsonData,
        required List<MapEntry<String, Map<String, dynamic>>> nestedClasses,
      }) {
    final className = _getClassName(config);
    final entityName = _getEntityClassName(config);

    // AutoMappr annotation
    if (config.createEntity &&
        config.mapperOption == MapperOption.autoMap &&
        config.isResponseType) {
      buffer.writeln('@AutoMappr([');
      buffer.writeln('  MapType<$className, $entityName>(),');

      for (final nested in nestedClasses) {
        final nestedModel = '${nested.key}DTO';
        final nestedEntity = '${nested.key}Entity';
        buffer.writeln('  MapType<$nestedModel, $nestedEntity>(),');
      }

      buffer.writeln('])');
    }

    buffer.writeln('@JsonSerializable()');
    buffer.writeln('class $className {');

    // Fields
    jsonData.forEach((key, value) {
      final fieldName = StringUtils.cleanFieldName(key);
      final fieldType = TypeResolver.resolveType(value, key, isModel: true);
      buffer.writeln("  @JsonKey(name: '$key')");
      buffer.writeln('  final $fieldType? $fieldName;');
    });

    buffer.writeln();

    // Constructor
    buffer.writeln('  $className({');
    jsonData.keys.forEach((key) {
      buffer.writeln('    required this.${StringUtils.cleanFieldName(key)},');
    });
    buffer.writeln('  });');
    buffer.writeln();

    // fromJson & toJson
    buffer.writeln('  factory $className.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$${className}FromJson(json);');
    buffer.writeln();
    buffer.writeln('  Map<String, dynamic> toJson() => _\$${className}ToJson(this);');

    // toEntity function (if Function mapper)
    if (config.createEntity &&
        config.mapperOption == MapperOption.function &&
        config.isResponseType) {
      buffer.writeln();
      buffer.writeln('  $entityName toEntity() {');
      buffer.writeln('    return $entityName(');
      jsonData.forEach((key, value) {
        final fieldName = StringUtils.cleanFieldName(key);
        final mapping = _generateFieldMapping(value, fieldName, false);
        buffer.writeln('      $fieldName: $mapping,');
      });
      buffer.writeln('    );');
      buffer.writeln('  }');
    }

    // AutoMappr variable (if needed)
    if (config.createEntity &&
        config.mapperOption == MapperOption.autoMap &&
        config.isResponseType) {
      buffer.writeln();
      buffer.writeln('static const mapper = \$$className();');
    }

    buffer.writeln('}');
    buffer.writeln();
  }

  static void _generateNestedClass(
      StringBuffer buffer, {
        required GenerationConfig config,
        required String nestedName,
        required Map<String, dynamic> jsonData,
      }) {
    final className = '${nestedName}DTO';
    final entityName = '${nestedName}Entity';

    buffer.writeln('@JsonSerializable()');
    buffer.writeln('class $className {');

    // Fields
    jsonData.forEach((key, value) {
      final fieldName = StringUtils.cleanFieldName(key);
      final fieldType = TypeResolver.resolveType(value, key, isModel: true);
      buffer.writeln("  @JsonKey(name: '$key')");
      buffer.writeln('  final $fieldType? $fieldName;');
    });

    buffer.writeln();

    // Constructor
    buffer.writeln('  $className({');
    jsonData.keys.forEach((key) {
      buffer.writeln('    required this.${StringUtils.cleanFieldName(key)},');
    });
    buffer.writeln('  });');
    buffer.writeln();

    // fromJson & toJson
    buffer.writeln('  factory $className.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$${className}FromJson(json);');
    buffer.writeln();
    buffer.writeln('  Map<String, dynamic> toJson() => _\$${className}ToJson(this);');

    // toEntity (if needed)
    if (config.createEntity &&
        config.mapperOption == MapperOption.function &&
        config.isResponseType) {
      buffer.writeln();
      buffer.writeln('  $entityName toEntity() {');
      buffer.writeln('    return $entityName(');
      jsonData.forEach((key, value) {
        final fieldName = StringUtils.cleanFieldName(key);
        final mapping = _generateFieldMapping(value, fieldName, false);
        buffer.writeln('      $fieldName: $mapping,');
      });
      buffer.writeln('    );');
      buffer.writeln('  }');
    }

    buffer.writeln('}');
    buffer.writeln();
  }

  static String _generateFieldMapping(
      dynamic value,
      String fieldName,
      bool isToRequest,
      ) {
    final method = isToRequest ? 'toRequest' : 'toEntity';

    if (TypeResolver.isNestedObject(value)) {
      return '$fieldName?.$method()';
    } else if (TypeResolver.isListOfObjects(value)) {
      return '$fieldName?.map((item) => item.$method()).toList()';
    }
    return fieldName;
  }

  static void _collectNestedClasses(
      Map<String, dynamic> json,
      List<MapEntry<String, Map<String, dynamic>>> nestedClasses,
      ) {
    json.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        final name = StringUtils.toPascalCase(key);
        if (!nestedClasses.any((e) => e.key == name)) {
          nestedClasses.add(MapEntry(name, value));
          _collectNestedClasses(value, nestedClasses);
        }
      } else if (value is List && value.isNotEmpty && value.first is Map) {
        final name = StringUtils.toPascalCase(key);
        final nestedJson = value.first as Map<String, dynamic>;
        if (!nestedClasses.any((e) => e.key == name)) {
          nestedClasses.add(MapEntry(name, nestedJson));
          _collectNestedClasses(nestedJson, nestedClasses);
        }
      }
    });
  }

  static String _getFilePath(GenerationConfig config) {
    final dir = config.isResponseType ? 'responses' : 'requests';
    final fileName = _getFileName(config);
    return '${config.modelPath}/$dir/$fileName.dart';
  }

  static String _getFileName(GenerationConfig config) {
    final name = StringUtils.toSnakeCase(config.modelName);
    final suffix = config.isResponseType ? '_response' : '_request';
    return '$name$suffix';
  }

  static String _getClassName(GenerationConfig config) {
    return StringUtils.toPascalCase(_getFileName(config));
  }

  static String _getEntityClassName(GenerationConfig config) {
    final name = StringUtils.toSnakeCase(config.entityName);
    final suffix = config.isResponseType ? '' : '_request';
    return StringUtils.toPascalCase('${name}${suffix}_entity');
  }

  static String _getRelativeEntityPath(GenerationConfig config) {
    final fileName = StringUtils.toSnakeCase(config.entityName);
    final suffix = config.isResponseType ? '' : '_request';
    return '${config.entityPath}/${fileName}${suffix}_entity.dart';
  }
}