import 'dart:io';
import 'package:mason/mason.dart';

import '../utils/file_paths.dart';

class GenerationConfig {
  final String modelName;
  final String entityName;
  final bool createEntity;
  final MapperOption mapperOption;
  final bool isResponseType;
  final String modelPath;
  final String entityPath;
  final String mapperPath;
  final String packageName;

  bool get createMapper => mapperOption != MapperOption.none;

  GenerationConfig({
    required this.modelName,
    required this.entityName,
    required this.createEntity,
    required this.mapperOption,
    required this.isResponseType,
    required this.modelPath,
    required this.entityPath,
    required this.mapperPath,
    required this.packageName,
  });

  factory GenerationConfig.fromContext(HookContext context) {
    final vars = context.vars;

    return GenerationConfig(
      modelName: vars['model_name'] as String,
      entityName: vars['model_name'] as String,
      createEntity: vars['create_entity'] as bool,
      mapperOption: _parseMapperOption(vars['create_mapper'] as String),
      isResponseType: vars['model_type'] as String == '1. Response',
      modelPath: FilePaths.modelPath,
      entityPath: FilePaths.entityPath,
      mapperPath: FilePaths.mapperPath,
      packageName: _getPackageName(context.logger),
    );
  }

  static MapperOption _parseMapperOption(String value) {
    if (value.startsWith('1.')) return MapperOption.none;
    if (value.startsWith('2.')) return MapperOption.function;
    if (value.startsWith('3.')) return MapperOption.extension;
    if (value.startsWith('4.')) return MapperOption.autoMap;
    return MapperOption.none;
  }

  static String _getPackageName(Logger logger) {
    try {
      final pubspecFile = File('pubspec.yaml');
      if (!pubspecFile.existsSync()) {
        logger.warn('pubspec.yaml not found, using directory name');
        return _getDirectoryName();
      }

      final content = pubspecFile.readAsStringSync();
      final lines = content.split('\n');
      final nameLine = lines.firstWhere(
            (line) => line.trim().startsWith('name:'),
        orElse: () => '',
      );

      if (nameLine.isEmpty) {
        return _getDirectoryName();
      }

      return nameLine.split(':')[1].trim();
    } catch (e) {
      logger.warn('Error reading package name: $e');
      return _getDirectoryName();
    }
  }

  static String _getDirectoryName() {
    final segments = Directory.current.uri.pathSegments;
    return segments.isNotEmpty ? segments.last : 'unknown_package';
  }
}

enum MapperOption {
  none,
  function,
  extension,
  autoMap,
}