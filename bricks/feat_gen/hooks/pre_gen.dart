import 'dart:io';

import 'package:mason/mason.dart';

import 'src/utils/dart_parser.dart';
import 'src/utils/file_paths.dart';
import 'src/utils/string_utils.dart';

void run(HookContext context) async {
  final logger = context.logger;

  // 1. Get inputs
  final featureName = context.vars['feature_name'] as String;
  final components = (context.vars['components'] as List).cast<String>();
  final dataSourceType = context.vars['data_source_type'] as String;
  String? dataSourceName;
  if (dataSourceType == 'Custom') {
    dataSourceName = logger.prompt('Enter data source name');
    context.vars['data_source_name'] = dataSourceName;
  }
  final dataType = dataSourceType == "Custom" ? StringUtils.toPascalCase(dataSourceName!) : dataSourceType;

  // 2. Validate dependencies
  final errors = <String>[];

  if (components.contains('2. UseCase') && !components.contains('1. Repository')) {
    errors.add('UseCase requires Repository');
  }

  if (components.contains('4. RepositoryImpl') &&
      !components.contains('1. Repository')) {
    errors.add('RepositoryImpl requires Repository');
  }

  if (components.contains('4. RepositoryImpl') &&
      !components.contains('3. DataSource')) {
    errors.add('RepositoryImpl requires DataSource');
  }

  if (components.contains('5. DataSourceImpl') &&
      !components.contains('3. DataSource')) {
    errors.add('DataSourceImpl requires DataSource');
  }

  if (errors.isNotEmpty) {
    for (final error in errors) {
      logger.err(error);
    }
    throw Exception('Invalid component selection');
  }

  logger.info('Component validation passed');

  // 3. Find and read dart_gen.dart
  final dartGenFile = File('dart_gen.dart');

  if (!dartGenFile.existsSync()) {
    logger.err('dart_gen.dart not found');
    throw Exception('Please create dart_gen.dart file first');
  }

  final content = await dartGenFile.readAsString();
  logger.info('Found dart_gen.dart');

  // 4. Parse dart_gen.dart
  final parser = DartParser(content);
  final imports = parser.extractImports();
  final dependencies = parser.extractDependencies();
  final methods = parser.extractMethods();

  logger.info('Found ${imports.length} imports');
  logger.info('Found ${dependencies.length} dependencies');
  logger.info('Found ${methods.length} methods');

  // 5. Check for existing files and prompt user
  final filePaths = FilePaths(featureName);
  final existingFiles = <String>[];

  if (components.contains('1. Repository') &&
      File(filePaths.repository).existsSync()) {
    existingFiles.add(filePaths.repository);
  }
  if (components.contains('2. UseCase') && File(filePaths.useCase).existsSync()) {
    existingFiles.add(filePaths.useCase);
  }
  if (components.contains('4. RepositoryImpl') &&
      File(filePaths.repositoryImpl).existsSync()) {
    existingFiles.add(filePaths.repositoryImpl);
  }
  if (components.contains('3. DataSource')){
    final path = FilePaths.dataSourceFile(featureName, dataType);
    if (File(path).existsSync()) {
      existingFiles.add(path);
    }
  }
  if (components.contains('5. DataSourceImpl')) {
    final path = FilePaths.dataSourceImplFile(featureName, dataType);
    if (File(path).existsSync()) {
      existingFiles.add(path);
    }
  }

  // 6. Warn about existing files
  if (existingFiles.isNotEmpty) {
    logger.warn('The following files already exist:');
    for (final file in existingFiles) {
      logger.warn('$file');
    }
    logger.info('');
    final shouldContinue = logger.confirm(
      'Do you want to update these files? (new methods/imports/dependencies will be added)',
      defaultValue: true,
    );

    if (!shouldContinue) {
      logger.info('Generation cancelled by user');
      exit(0);
    }
  }

  // 7. Ask for use case names (one per method)
  final useCaseNames = <String, String>{};

  if (components.contains('2. UseCase') && methods.isNotEmpty) {
    logger.info('');
    logger.info('Please provide use case names for each method:');
    for (final method in methods) {
      final defaultName = method['name'] as String;
      final useCaseName = logger.prompt(
        'Use case name for "${method['name']}" method:',
        defaultValue: defaultName,
      );
      useCaseNames[method['name'] as String] =
          '${StringUtils.toPascalCase(useCaseName)}UseCase';
    }
  }

  // 8. Store parsed data in context
  context.vars = {
    ...context.vars,
    'parsed_imports': imports,
    'parsed_dependencies': dependencies,
    'parsed_methods': methods,
    'existing_files': existingFiles,
    'use_case_names': useCaseNames,
  };

  logger.success('Pre-generation validation complete');
}