import 'dart:convert';
import 'dart:io';
import 'package:mason/mason.dart';

void run(HookContext context) {
  final logger = context.logger;

  final modelName = context.vars['model_name'] as String;
  final entityName = context.vars['model_name'] as String;
  final createEntity = context.vars['create_entity'] as bool;
  final modelType = context.vars['model_type'] as String == '1. Response';

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
      ? Directory('lib/api/models/responses')
      : Directory('lib/api/models/requests');

  final entityDir = Directory('lib/domain/entities');

  modelDir.createSync(recursive: true);
  if (createEntity) entityDir.createSync(recursive: true);

  final modelFile = File(
    '${modelDir.path}/${_toSnakeCase(modelName)}${modelType ? '_response' : '_request'}.dart',
  );

  final entityFile = File(
    '${entityDir.path}/${_toSnakeCase(entityName)}${modelType ? '' : '_request'}_entity.dart',
  );

  final bufferModel = StringBuffer();
  final bufferEntity = StringBuffer();

  // Generate imports
  bufferModel.writeln("import 'package:json_annotation/json_annotation.dart';");
  bufferModel.writeln('');
  bufferModel.writeln(
      "part '${_toSnakeCase(modelName)}${modelType ? '_response' : '_request'}.g.dart';");
  bufferModel.writeln('');

  // Generate model and entity recursively
  _generateClassRecursive(
    bufferModel,
    bufferEntity,
    className:
    '${_toPascalCase(modelName)}${modelType ? 'Response' : 'Request'}',
    entityName:
    '${_toPascalCase(entityName)}${modelType ? '' : 'Request'}Entity',
    json: jsonMap,
    createEntity: createEntity,
  );

  // Write files
  modelFile.writeAsStringSync(bufferModel.toString());
  if (createEntity) entityFile.writeAsStringSync(bufferEntity.toString());

  // Format code
  _formatFile(modelFile);
  if (createEntity) _formatFile(entityFile);

  logger.success('Model generated at: ${modelFile.path}');
  if (createEntity) logger.success('Entity generated at: ${entityFile.path}');
}

void _generateClassRecursive(
    StringBuffer modelBuffer,
    StringBuffer entityBuffer, {
      required String className,
      required String entityName,
      required Map<String, dynamic> json,
      required bool createEntity,
    }) {
  // === MODEL CLASS ===
  modelBuffer.writeln('@JsonSerializable()');
  modelBuffer.writeln('class $className {');

  json.forEach((key, value) {
    final dartFieldName = _fieldName(key);
    modelBuffer.writeln("  @JsonKey(name: '$key')");
    modelBuffer.writeln('  final ${_getType(value, key)} $dartFieldName;');
  });

  modelBuffer.writeln('');
  modelBuffer.writeln('  $className({');
  json.keys.forEach((key) {
    modelBuffer.writeln('    required this.${_fieldName(key)},');
  });
  modelBuffer.writeln('  });\n');

  modelBuffer.writeln(
      '  factory $className.fromJson(Map<String, dynamic> json) => _\$${className}FromJson(json);');
  modelBuffer.writeln(
      '  Map<String, dynamic> toJson() => _\$${className}ToJson(this);');
  modelBuffer.writeln('}\n');

  // === ENTITY CLASS ===
  if (createEntity) {
    entityBuffer.writeln('class $entityName {');

    json.forEach((key, value) {
      entityBuffer.writeln('  final ${_getType(value, key)} ${_fieldName(key)};');
    });

    entityBuffer.writeln('');
    entityBuffer.writeln('  $entityName({');
    json.keys.forEach((key) {
      entityBuffer.writeln('    required this.${_fieldName(key)},');
    });
    entityBuffer.writeln('  });');
    entityBuffer.writeln('}\n');
  }

  // === Generate nested classes if needed ===
  json.forEach((key, value) {
    if (value is Map<String, dynamic>) {
      final nestedName = _toPascalCase(key);
      _generateClassRecursive(modelBuffer, entityBuffer,
          className: nestedName,
          entityName: nestedName,
          json: value,
          createEntity: createEntity);
    } else if (value is List && value.isNotEmpty && value.first is Map) {
      final nestedName = _toPascalCase(key);
      _generateClassRecursive(modelBuffer, entityBuffer,
          className: nestedName,
          entityName: nestedName,
          json: value.first as Map<String, dynamic>,
          createEntity: createEntity);
    }
  });
}

String _fieldName(String key) {
  if (key.startsWith('_')) {
    final clean = key.replaceFirst('_', '');
    return _toCamelCase(clean);
  }
  return _toCamelCase(key);
}

String _getType(dynamic value, String key) {
  if (value is bool) return 'bool';
  if (value is int || value is double) return 'num';
  if (value is String) return 'String';
  if (value is List) {
    if (value.isEmpty) return 'List<dynamic>';
    final first = value.first;
    if (first is Map) return 'List<${_toPascalCase(key)}>';
    if (first is bool) return 'List<bool>';
    if (first is int || first is double) return 'List<num>';
    if (first is String) return 'List<String>';
    return 'List<dynamic>';
  }
  if (value is Map) return _toPascalCase(key);
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