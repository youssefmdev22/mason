import 'dart:io';
import 'package:mason/mason.dart';
import '../models/generation_config.dart';
import '../utils/string_utils.dart';
import '../utils/type_resolver.dart';
import '../utils/file_utils.dart';

class MapperGenerator {
  static void generate({
    required GenerationConfig config,
    required Map<String, dynamic> jsonData,
    required List<MapEntry<String, Map<String, dynamic>>> nestedClasses,
    required String modelFilePath,
    required Logger logger,
  }) {
    // Only generate for extension mapper
    if (config.mapperOption != MapperOption.extension) return;

    final buffer = StringBuffer();

    // Generate imports
    _generateImports(buffer, config, modelFilePath);

    // Generate main extension
    _generateMainExtension(
      buffer,
      config: config,
      jsonData: jsonData,
    );

    // Generate nested extensions
    for (final nested in nestedClasses) {
      _generateNestedExtension(
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
        logger.info('Skipped generating mapper (file already exists).');
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
        logger.info('Skipped generating mapper (file already exists).');
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
    logger.success('Mapper generated: $filePath');
  }

  static void _generateImports(
      StringBuffer buffer,
      GenerationConfig config,
      String modelFilePath,
      ) {
    final entityPath = _getEntityFilePath(config);

    // Import paths relative to package
    final modelImport = modelFilePath.substring(
      modelFilePath.indexOf('/') + 1,
    );
    final entityImport = entityPath.substring(
      entityPath.indexOf('/') + 1,
    );

    buffer.writeln("import 'package:${config.packageName}/$entityImport';");
    buffer.writeln("import 'package:${config.packageName}/$modelImport';");
    buffer.writeln();
  }

  static void _generateMainExtension(
      StringBuffer buffer, {
        required GenerationConfig config,
        required Map<String, dynamic> jsonData,
      }) {
    final modelClass = _getModelClassName(config);
    final entityClass = _getEntityClassName(config);

    if (config.isResponseType) {
      // Response: Model -> Entity
      buffer.writeln('extension ${modelClass}Mapper on $modelClass {');
      buffer.writeln('  $entityClass toEntity() {');
      buffer.writeln('    return $entityClass(');

      jsonData.forEach((key, value) {
        final fieldName = StringUtils.cleanFieldName(key);
        final mapping = _generateFieldMapping(value, fieldName, false);
        buffer.writeln('      $fieldName: $mapping,');
      });

      buffer.writeln('    );');
      buffer.writeln('  }');
      buffer.writeln('}');
      buffer.writeln();
    } else {
      // Request: Entity -> Model
      buffer.writeln('extension ${entityClass}Mapper on $entityClass {');
      buffer.writeln('  $modelClass toRequest() {');
      buffer.writeln('    return $modelClass(');

      jsonData.forEach((key, value) {
        final fieldName = StringUtils.cleanFieldName(key);
        final mapping = _generateFieldMapping(value, fieldName, true);
        buffer.writeln('      $fieldName: $mapping,');
      });

      buffer.writeln('    );');
      buffer.writeln('  }');
      buffer.writeln('}');
      buffer.writeln();
    }
  }

  static void _generateNestedExtension(
      StringBuffer buffer, {
        required GenerationConfig config,
        required String nestedName,
        required Map<String, dynamic> jsonData,
      }) {
    final modelClass = '${nestedName}DTO';
    final entityClass = '${nestedName}Entity';

    if (config.isResponseType) {
      // Response: Model -> Entity
      buffer.writeln('extension ${modelClass}Mapper on $modelClass {');
      buffer.writeln('  $entityClass toEntity() {');
      buffer.writeln('    return $entityClass(');

      jsonData.forEach((key, value) {
        final fieldName = StringUtils.cleanFieldName(key);
        final mapping = _generateFieldMapping(value, fieldName, false);
        buffer.writeln('      $fieldName: $mapping,');
      });

      buffer.writeln('    );');
      buffer.writeln('  }');
      buffer.writeln('}');
      buffer.writeln();
    } else {
      // Request: Entity -> Model
      buffer.writeln('extension ${entityClass}Mapper on $entityClass {');
      buffer.writeln('  $modelClass toRequest() {');
      buffer.writeln('    return $modelClass(');

      jsonData.forEach((key, value) {
        final fieldName = StringUtils.cleanFieldName(key);
        final mapping = _generateFieldMapping(value, fieldName, true);
        buffer.writeln('      $fieldName: $mapping,');
      });

      buffer.writeln('    );');
      buffer.writeln('  }');
      buffer.writeln('}');
      buffer.writeln();
    }
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

  static String _getFilePath(GenerationConfig config) {
    final fileName = config.isResponseType
        ? '${StringUtils.toSnakeCase(config.modelName)}_mapper'
        : '${StringUtils.toSnakeCase(config.entityName)}_mapper';
    return '${config.mapperPath}/$fileName.dart';
  }

  static String _getEntityFilePath(GenerationConfig config) {
    final name = StringUtils.toSnakeCase(config.entityName);
    final suffix = config.isResponseType ? '' : '_request';
    return '${config.entityPath}/${name}${suffix}_entity.dart';
  }

  static String _getModelClassName(GenerationConfig config) {
    final name = StringUtils.toSnakeCase(config.modelName);
    final suffix = config.isResponseType ? '_response' : '_request';
    return StringUtils.toPascalCase('$name$suffix');
  }

  static String _getEntityClassName(GenerationConfig config) {
    final name = StringUtils.toSnakeCase(config.entityName);
    final suffix = config.isResponseType ? '' : '_request';
    return StringUtils.toPascalCase('${name}${suffix}_entity');
  }
}