import 'package:mason/mason.dart';
import 'src/generators/data_source_generator.dart';
import 'src/generators/data_source_impl_generator.dart';
import 'src/generators/repository_generator.dart';
import 'src/generators/repository_impl_generator.dart';
import 'src/generators/use_case_generator.dart';
import 'src/utils/file_paths.dart';
import 'src/utils/string_utils.dart';

void run(HookContext context) async {
  final logger = context.logger;

  // 1. Get data from pre_gen hook
  final featureName = context.vars['feature_name'] as String;
  final components = (context.vars['components'] as List).cast<String>();
  final dataSourceType = context.vars['data_source_type'] as String;
  final dataSourceName = context.vars['data_source_name'] as String?;
  final dataType = dataSourceType == "Custom" ? StringUtils.toPascalCase(dataSourceName!) : dataSourceType;

  final imports = (context.vars['parsed_imports'] as List).cast<String>();

  // Fix type casting for dependencies
  final dependenciesList = context.vars['parsed_dependencies'] as List;
  final dependencies = dependenciesList.map((e) {
    final map = e as Map;
    return {
      'type': map['type'] as String,
      'name': map['name'] as String,
    };
  }).toList();

  // Fix type casting for methods
  final methodsList = context.vars['parsed_methods'] as List;
  final methods = methodsList.map((e) => e as Map<String, dynamic>).toList();

  // Fix type casting for use case names
  final useCaseNamesMap = context.vars['use_case_names'] as Map;
  final useCaseNames = useCaseNamesMap.map(
        (key, value) => MapEntry(key as String, value as String),
  );

  final filePaths = FilePaths(featureName);
  final generatedFiles = <String>[];

  logger.info('');
  logger.info('Starting file generation...');
  logger.info('');

  // 2. Generate Repository
  if (components.contains('1. Repository')) {
    final generator = RepositoryGenerator(
      featureName: featureName,
      imports: imports,
      methods: methods,
    );
    await generator.generate(filePaths.repository, logger);
    generatedFiles.add(filePaths.repository);
  }

  // 3. Generate Use Cases (separate file for each method)
  if (components.contains('2. UseCase')) {
    final generator = UseCaseGenerator(
      featureName: featureName,
      imports: imports,
      methods: methods,
      useCaseNames: useCaseNames,
    );
    final useCaseFiles = await generator.generate(logger);
    generatedFiles.addAll(useCaseFiles);
  }

  // 4. Generate Data Source
  if (components.contains('3. DataSource')) {
    final path = FilePaths.dataSourceFile(featureName, dataType);
    final generator = DataSourceGenerator(
      featureName: featureName,
      type: dataType,
      imports: imports,
      methods: methods,
    );
    await generator.generate(path, logger);
    generatedFiles.add(path);
  }

  // 5. Generate Repository Implementation
  if (components.contains('4. RepositoryImpl')) {
    final generator = RepositoryImplGenerator(
      featureName: featureName,
      type: dataType,
      imports: imports,
      methods: methods,
    );
    await generator.generate(filePaths.repositoryImpl, logger);
    generatedFiles.add(filePaths.repositoryImpl);
  }

  // 6. Generate Data Source Implementations
  if (components.contains('5. DataSourceImpl')) {
    final path = FilePaths.dataSourceImplFile(featureName, dataType);
    final generator = DataSourceImplGenerator(
      featureName: featureName,
      type: dataType,
      imports: imports,
      dependencies: dependencies,
      methods: methods,
    );
    await generator.generate(path, logger);
    generatedFiles.add(path);
  }

  // 7. Summary
  logger.info('');
  logger.success('Successfully generated ${generatedFiles.length} files:');
  for (final file in generatedFiles) {
    logger.info('$file');
  }
  logger.info('');
}