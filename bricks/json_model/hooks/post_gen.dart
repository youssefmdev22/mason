import 'dart:convert';
import 'dart:io';

import 'package:mason/mason.dart';

void run(HookContext context) {
  final logger = context.logger;

  final modelName = context.vars['model_name'] as String;
  final entityName = context.vars['model_name'] as String;
  final createEntity = context.vars['create_entity'] as bool;
  final createMapperValue = context.vars['create_mapper'] as String;
  final modelType = context.vars['model_type'] as String == '1. Response';
  final modelPath = context.vars['model_path'] as String;
  final entityPath = context.vars['entity_path'] as String;
  final mapperPath = context.vars['mapper_path'] as String;

  // Parse mapper option
  final mapperOption = _parseMapperOption(createMapperValue);

  // Get package name
  String? packageName;
  try {
    final pubspecFile = File('pubspec.yaml');

    if (!pubspecFile.existsSync()) {
      logger.err('pubspec.yaml not found in current directory.');
      return;
    }

    final yamlContent = pubspecFile.readAsStringSync();
    final yamlLines = yamlContent.split('\n');
    final packageLine =
        yamlLines.firstWhere((line) => line.startsWith('name:'));
    packageName = packageLine.split(':')[1].trim();
  } catch (_) {}
  packageName ??= Directory.current.uri.pathSegments.isNotEmpty
      ? Directory.current.uri.pathSegments.last
      : 'unknown_package';
  context.vars['package_name'] = packageName;

  // Read JSON from file
  final jsonFile = File('json_gen.json');
  if (!jsonFile.existsSync()) {
    logger.err('Missing json_gen.json file in root directory.');
    return;
  }

  late final Map<String, dynamic> jsonMap;
  try {
    final content = jsonFile.readAsStringSync();
    jsonMap = json.decode(content);
  } catch (e) {
    logger.err('Invalid JSON format: $e');
    return;
  }

  // Determine file paths
  final modelDir = modelType
      ? Directory('$modelPath/responses')
      : Directory('$modelPath/requests');

  final entityDir = Directory(entityPath);

  modelDir.createSync(recursive: true);
  if (createEntity) entityDir.createSync(recursive: true);

  final modelFileName =
      '${_toSnakeCase(modelName)}${modelType ? '_response' : '_request'}';
  final modelFile = File('${modelDir.path}/$modelFileName.dart');

  final entityFileName =
      '${_toSnakeCase(entityName)}${modelType ? '' : '_request'}_entity';
  final entityFile = File('${entityDir.path}/$entityFileName.dart');

  final bufferModel = StringBuffer();
  final bufferEntity = StringBuffer();

  final nestedClasses = <MapEntry<String, Map<String, dynamic>>>[];

  // Generate imports for model
  if (createEntity && mapperOption == MapperOption.autoMap && modelType ||
      createEntity && mapperOption == MapperOption.function && modelType) {
    bufferModel.writeln(
        "import 'package:$packageName/${entityFile.path.substring(entityFile.path.indexOf('/') + 1)}';");
  } else if (createEntity &&
          mapperOption == MapperOption.autoMap &&
          !modelType ||
      createEntity && mapperOption == MapperOption.function && !modelType) {
    bufferEntity.writeln(
        "import 'package:$packageName/${modelFile.path.substring(modelFile.path.indexOf('/') + 1)}';");
  }
  bufferModel.writeln("import 'package:json_annotation/json_annotation.dart';");
  if (createEntity && mapperOption == MapperOption.autoMap && modelType) {
    bufferModel.writeln(
        "import 'package:auto_mappr_annotation/auto_mappr_annotation.dart';");
    bufferModel.writeln("import '$modelFileName.auto_mappr.dart';");
  } else if (createEntity &&
      mapperOption == MapperOption.autoMap &&
      !modelType) {
    bufferEntity.writeln(
        "import 'package:auto_mappr_annotation/auto_mappr_annotation.dart';");
    bufferEntity.writeln("import '$entityFileName.auto_mappr.dart';");
  }
  bufferModel.writeln('');
  bufferModel.writeln("part '$modelFileName.g.dart';");
  bufferModel.writeln('');

  // Collect all nested classes first before generating anything
  _collectNestedClasses(jsonMap, nestedClasses);

  // Generate model and entity recursively
  _generateClassRecursive(
    bufferModel,
    bufferEntity,
    className: '${_toPascalCase(modelFileName)}',
    entityName: '${_toPascalCase(entityFileName)}',
    json: jsonMap,
    createEntity: createEntity,
    nestedClasses: nestedClasses,
    isRoot: true,
    modelType: modelType,
    mapperOption: mapperOption,
  );

  // Write files
  modelFile.writeAsStringSync(bufferModel.toString());
  if (createEntity) entityFile.writeAsStringSync(bufferEntity.toString());

  // Generate extension mapper file if needed
  if (createEntity && mapperOption == MapperOption.extension) {
    final mapperDir = Directory(mapperPath);
    mapperDir.createSync(recursive: true);

    final mapperFileName = modelType
        ? '${_toSnakeCase(modelName)}_mapper'
        : '${_toSnakeCase(entityName)}_mapper';
    final mapperFile = File('${mapperDir.path}/$mapperFileName.dart');

    final bufferMapper = StringBuffer();
    _generateExtensionMapper(
      buffer: bufferMapper,
      modelType: modelType,
      modelClassName: _toPascalCase(modelFileName),
      entityClassName: _toPascalCase(entityFileName),
      json: jsonMap,
      nestedClasses: nestedClasses,
      modelFileName: modelFileName,
      entityFileName: entityFileName,
      modelFile: modelFile,
      entityFile: entityFile,
      packageName: packageName,
    );

    mapperFile.writeAsStringSync(bufferMapper.toString());
    _formatFile(mapperFile);
    logger.success('Mapper generated at: ${mapperFile.path}');
  }

  // Format code
  _formatFile(modelFile);
  if (createEntity) _formatFile(entityFile);

  logger.success('Model generated at: ${modelFile.path}');
  if (createEntity) logger.success('Entity generated at: ${entityFile.path}');
}

enum MapperOption {
  none,
  function,
  extension,
  autoMap,
}

MapperOption _parseMapperOption(String value) {
  if (value.startsWith('1.')) return MapperOption.none;
  if (value.startsWith('2.')) return MapperOption.function;
  if (value.startsWith('3.')) return MapperOption.extension;
  if (value.startsWith('4.')) return MapperOption.autoMap;
  return MapperOption.none;
}

void _generateClassRecursive(
  StringBuffer modelBuffer,
  StringBuffer entityBuffer, {
  required String className,
  required String entityName,
  required Map<String, dynamic> json,
  required bool createEntity,
  required List<MapEntry<String, Map<String, dynamic>>> nestedClasses,
  required bool isRoot,
  required bool modelType,
  required MapperOption mapperOption,
}) {
  // === MODEL CLASS ===

  // Add AutoMappr annotations for root class
  if (isRoot &&
      createEntity &&
      mapperOption == MapperOption.autoMap &&
      modelType) {
    modelBuffer.writeln('@AutoMappr([');
    modelBuffer.writeln('  MapType<$className, $entityName>(),');

    // Add MapType for all nested classes
    for (final nested in nestedClasses) {
      final nestedModelName = '${nested.key}DTO';
      final nestedEntityName = '${nested.key}Entity';
      modelBuffer.writeln('  MapType<$nestedModelName, $nestedEntityName>(),');
    }

    modelBuffer.writeln('])');
  }

  modelBuffer.writeln('@JsonSerializable()');
  modelBuffer.writeln('class $className {');

  json.forEach((key, value) {
    final dartFieldName = _fieldName(key);
    final fieldType = _getType(value, key, true);
    modelBuffer.writeln("  @JsonKey(name: '$key')");
    modelBuffer.writeln('  final $fieldType $dartFieldName;');
  });

  modelBuffer.writeln('');
  modelBuffer.writeln('  $className({');
  json.keys.forEach((key) {
    modelBuffer.writeln('    required this.${_fieldName(key)},');
  });
  modelBuffer.writeln('  });\n');

  modelBuffer.writeln(
      '  factory $className.fromJson(Map<String, dynamic> json) => _\$${className}FromJson(json);');
  modelBuffer.writeln('');
  modelBuffer.writeln(
      '  Map<String, dynamic> toJson() => _\$${className}ToJson(this);');

  // Add toEntity function if Function mapper and Response type
  if (isRoot &&
      createEntity &&
      mapperOption == MapperOption.function &&
      modelType) {
    modelBuffer.writeln('');
    modelBuffer.writeln('  $entityName toEntity() {');
    modelBuffer.writeln('    return $entityName(');
    json.forEach((key, value) {
      final fieldName = _fieldName(key);
      final mapping = _generateFieldMapping(value, key, fieldName, false);
      modelBuffer.writeln('      $fieldName: $mapping,');
    });
    modelBuffer.writeln('    );');
    modelBuffer.writeln('  }');
  }

  modelBuffer.writeln('}\n');

  // === ENTITY CLASS ===
  if (createEntity) {
    if (isRoot && mapperOption == MapperOption.autoMap && !modelType) {
      entityBuffer.writeln('@AutoMappr([');
      entityBuffer.writeln('  MapType<$entityName, $className>(),');

      // Add MapType for all nested classes
      for (final nested in nestedClasses) {
        final nestedModelName = '${nested.key}DTO';
        final nestedEntityName = '${nested.key}Entity';
        entityBuffer
            .writeln('  MapType<$nestedEntityName, $nestedModelName>(),');
      }

      entityBuffer.writeln('])');
    }
    entityBuffer.writeln('class $entityName {');

    json.forEach((key, value) {
      final fieldType = _getType(value, key, false);
      entityBuffer.writeln('  final $fieldType ${_fieldName(key)};');
    });

    entityBuffer.writeln('');
    entityBuffer.writeln('  $entityName({');
    json.keys.forEach((key) {
      entityBuffer.writeln('    required this.${_fieldName(key)},');
    });
    entityBuffer.writeln('  });');

    // Add toRequest function if Function mapper and Request type
    if (isRoot && mapperOption == MapperOption.function && !modelType) {
      entityBuffer.writeln('');
      entityBuffer.writeln('  $className toRequest() {');
      entityBuffer.writeln('    return $className(');
      json.forEach((key, value) {
        final fieldName = _fieldName(key);
        final mapping = _generateFieldMapping(value, key, fieldName, true);
        entityBuffer.writeln('      $fieldName: $mapping,');
      });
      entityBuffer.writeln('    );');
      entityBuffer.writeln('  }');
    }

    entityBuffer.writeln('}\n');
  }

  // === Generate nested classes (already collected in run()) ===
  if (isRoot) {
    for (final nested in nestedClasses) {
      _generateNestedClass(
        modelBuffer,
        entityBuffer,
        nestedName: nested.key,
        json: nested.value,
        createEntity: createEntity,
        modelType: modelType,
        mapperOption: mapperOption,
      );
    }
  }
}

void _generateNestedClass(
  StringBuffer modelBuffer,
  StringBuffer entityBuffer, {
  required String nestedName,
  required Map<String, dynamic> json,
  required bool createEntity,
  required bool modelType,
  required MapperOption mapperOption,
}) {
  final modelClassName = '${nestedName}DTO';
  final entityClassName = '${nestedName}Entity';

  // === NESTED MODEL CLASS ===
  modelBuffer.writeln('@JsonSerializable()');
  modelBuffer.writeln('class $modelClassName {');

  json.forEach((key, value) {
    final dartFieldName = _fieldName(key);
    final fieldType = _getType(value, key, true);
    modelBuffer.writeln("  @JsonKey(name: '$key')");
    modelBuffer.writeln('  final $fieldType $dartFieldName;');
  });

  modelBuffer.writeln('');
  modelBuffer.writeln('  $modelClassName({');
  json.keys.forEach((key) {
    modelBuffer.writeln('    required this.${_fieldName(key)},');
  });
  modelBuffer.writeln('  });\n');

  modelBuffer.writeln(
      '  factory $modelClassName.fromJson(Map<String, dynamic> json) => _\$${modelClassName}FromJson(json);');
  modelBuffer.writeln('');
  modelBuffer.writeln(
      '  Map<String, dynamic> toJson() => _\$${modelClassName}ToJson(this);');

  // Add toEntity function for nested if Function mapper and Response type
  if (createEntity && mapperOption == MapperOption.function && modelType) {
    modelBuffer.writeln('');
    modelBuffer.writeln('  $entityClassName toEntity() {');
    modelBuffer.writeln('    return $entityClassName(');
    json.forEach((key, value) {
      final fieldName = _fieldName(key);
      final mapping = _generateFieldMapping(value, key, fieldName, false);
      modelBuffer.writeln('      $fieldName: $mapping,');
    });
    modelBuffer.writeln('    );');
    modelBuffer.writeln('  }');
  }

  modelBuffer.writeln('}\n');

  // === NESTED ENTITY CLASS ===
  if (createEntity) {
    entityBuffer.writeln('class $entityClassName {');

    json.forEach((key, value) {
      final fieldType = _getType(value, key, false);
      entityBuffer.writeln('  final $fieldType ${_fieldName(key)};');
    });

    entityBuffer.writeln('');
    entityBuffer.writeln('  $entityClassName({');
    json.keys.forEach((key) {
      entityBuffer.writeln('    required this.${_fieldName(key)},');
    });
    entityBuffer.writeln('  });');

    // Add toRequest function for nested if Function mapper and Request type
    if (mapperOption == MapperOption.function && !modelType) {
      entityBuffer.writeln('');
      entityBuffer.writeln('  $modelClassName toRequest() {');
      entityBuffer.writeln('    return $modelClassName(');
      json.forEach((key, value) {
        final fieldName = _fieldName(key);
        final mapping = _generateFieldMapping(value, key, fieldName, true);
        entityBuffer.writeln('      $fieldName: $mapping,');
      });
      entityBuffer.writeln('    );');
      entityBuffer.writeln('  }');
    }

    entityBuffer.writeln('}\n');
  }
}

String _generateFieldMapping(
  dynamic value,
  String key,
  String fieldName,
  bool isToRequest,
) {
  final methodName = isToRequest ? 'toRequest' : 'toEntity';

  if (value is Map<String, dynamic>) {
    // Nested object
    return '$fieldName.$methodName()';
  } else if (value is List && value.isNotEmpty && value.first is Map) {
    // List of objects
    return '$fieldName.map((item) => item.$methodName()).toList()';
  } else {
    // Primitive type
    return fieldName;
  }
}

void _generateExtensionMapper(
    {required StringBuffer buffer,
    required bool modelType,
    required String modelClassName,
    required String entityClassName,
    required Map<String, dynamic> json,
    required List<MapEntry<String, Map<String, dynamic>>> nestedClasses,
    required File modelFile,
    required String modelFileName,
    required File entityFile,
    required String entityFileName,
    required String packageName}) {
  // Import statements

  buffer.writeln(
      "import 'package:$packageName/${entityFile.path.substring(entityFile.path.indexOf('/') + 1)}';");
  buffer.writeln(
      "import 'package:$packageName/${modelFile.path.substring(modelFile.path.indexOf('/') + 1)}';");
  buffer.writeln('');

  if (modelType) {
    // Response: extension on model with toEntity
    buffer.writeln('extension ${modelClassName}Mapper on $modelClassName {');
    buffer.writeln('  $entityClassName toEntity() {');
    buffer.writeln('    return $entityClassName(');
    json.forEach((key, value) {
      final fieldName = _fieldName(key);
      final mapping = _generateFieldMapping(value, key, fieldName, false);
      buffer.writeln('      $fieldName: $mapping,');
    });
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln('}\n');

    // Generate nested extensions
    for (final nested in nestedClasses) {
      final nestedModelName = '${nested.key}DTO';
      final nestedEntityName = '${nested.key}Entity';

      buffer
          .writeln('extension ${nestedModelName}Mapper on $nestedModelName {');
      buffer.writeln('  $nestedEntityName toEntity() {');
      buffer.writeln('    return $nestedEntityName(');
      nested.value.forEach((key, value) {
        final fieldName = _fieldName(key);
        final mapping = _generateFieldMapping(value, key, fieldName, false);
        buffer.writeln('      $fieldName: $mapping,');
      });
      buffer.writeln('    );');
      buffer.writeln('  }');
      buffer.writeln('}\n');
    }
  } else {
    // Request: extension on entity with toRequest
    buffer.writeln('extension ${entityClassName}Mapper on $entityClassName {');
    buffer.writeln('  $modelClassName toRequest() {');
    buffer.writeln('    return $modelClassName(');
    json.forEach((key, value) {
      final fieldName = _fieldName(key);
      final mapping = _generateFieldMapping(value, key, fieldName, true);
      buffer.writeln('      $fieldName: $mapping,');
    });
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln('}\n');

    // Generate nested extensions
    for (final nested in nestedClasses) {
      final nestedModelName = '${nested.key}DTO';
      final nestedEntityName = '${nested.key}Entity';

      buffer.writeln(
          'extension ${nestedEntityName}Mapper on $nestedEntityName {');
      buffer.writeln('  $nestedModelName toRequest() {');
      buffer.writeln('    return $nestedModelName(');
      nested.value.forEach((key, value) {
        final fieldName = _fieldName(key);
        final mapping = _generateFieldMapping(value, key, fieldName, true);
        buffer.writeln('      $fieldName: $mapping,');
      });
      buffer.writeln('    );');
      buffer.writeln('  }');
      buffer.writeln('}\n');
    }
  }
}

String _fieldName(String key) {
  if (key.startsWith('_')) {
    final clean = key.replaceFirst('_', '');
    return _toCamelCase(clean);
  }
  return _toCamelCase(key);
}

String _getType(dynamic value, String key, bool isModel) {
  if (value is bool) return 'bool';
  if (value is int || value is double) return 'num';
  if (value is String) return 'String';
  if (value is List) {
    if (value.isEmpty) return 'List<dynamic>';
    final first = value.first;
    final suffix = isModel ? 'DTO' : 'Entity';
    if (first is Map) return 'List<${_toPascalCase(key)}$suffix>';
    if (first is bool) return 'List<bool>';
    if (first is int || first is double) return 'List<num>';
    if (first is String) return 'List<String>';
    return 'List<dynamic>';
  }
  if (value is Map) {
    final suffix = isModel ? 'DTO' : 'Entity';
    return '${_toPascalCase(key)}$suffix';
  }
  return 'String';
}

String _toCamelCase(String input) {
  input = input.replaceAll(RegExp(r'^_+'), '');
  final parts = input.split(RegExp(r'[_\s]+'));
  return parts.first +
      parts
          .skip(1)
          .map((p) =>
              p.isNotEmpty ? '${p[0].toUpperCase()}${p.substring(1)}' : '')
          .join();
}

String _toSnakeCase(String input) {
  return input
      .replaceAllMapped(
          RegExp(r'([A-Z])'), (m) => '_${m.group(0)!.toLowerCase()}')
      .replaceFirst('_', '')
      .toLowerCase();
}

String _toPascalCase(String input) {
  return input
      .split(RegExp(r'[_\s-]+'))
      .map((w) => w.isEmpty
          ? ''
          : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join();
}

void _formatFile(File file) {
  try {
    Process.runSync('dart', ['format', file.path]);
  } catch (_) {}
}

void _collectNestedClasses(
  Map<String, dynamic> json,
  List<MapEntry<String, Map<String, dynamic>>> nestedClasses,
) {
  json.forEach((key, value) {
    if (value is Map<String, dynamic>) {
      final nestedName = _toPascalCase(key);
      // Check if already exists to avoid duplicates
      if (!nestedClasses.any((entry) => entry.key == nestedName)) {
        nestedClasses.add(MapEntry(nestedName, value));
      }
      // Recursively collect nested classes within nested classes
      _collectNestedClasses(value, nestedClasses);
    } else if (value is List && value.isNotEmpty && value.first is Map) {
      final nestedName = _toPascalCase(key);
      final nestedJson = value.first as Map<String, dynamic>;
      // Check if already exists to avoid duplicates
      if (!nestedClasses.any((entry) => entry.key == nestedName)) {
        nestedClasses.add(MapEntry(nestedName, nestedJson));
      }
      // Recursively collect nested classes within nested classes
      _collectNestedClasses(nestedJson, nestedClasses);
    }
  });
}
