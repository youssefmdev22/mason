import 'package:mason/mason.dart';

void run(HookContext context) async {
  final logger = context.logger;

  final modelName = context.vars['model_name'] as String;

  final modelType = logger.chooseOne(
    'What is the model type?',
    choices: ['1. Response', '2. Request'],
    defaultValue: '1. Response',
  );

  final createEntity = logger.confirm('Do you want to create entity?', defaultValue: true);

  if (!createEntity) {
    final modelPath = logger.prompt(
      'Enter the path for model file',
      defaultValue: 'lib/api/models',
    );

    context.vars = {
      'model_name': modelName,
      'model_type': modelType,
      'create_entity': false,
      'create_mapper': '1. No',
      'model_path': modelPath,
      'entity_path': 'lib/domain/entities',
      'mapper_path': 'lib/api/mappers',
    };

    logger.info('Skipping entity and mapper creation. Only model will be generated.');
    return;
  }

  final createMapper = logger.chooseOne(
    'Do you want to add mapper?',
    choices: ['1. No', '2. Function', '3. Extension', '4. AutoMap'],
    defaultValue: '1. No',
  );

  final modelPath = logger.prompt(
    'Enter the path for model file',
    defaultValue: 'lib/api/models',
  );

  final entityPath = logger.prompt(
    'Enter the path for entity file',
    defaultValue: 'lib/domain/entities',
  );

  final mapperPath = logger.prompt(
    'Enter the path for mapper file',
    defaultValue: 'lib/api/mappers',
  );

  context.vars = {
    'model_name': modelName,
    'model_type': modelType,
    'create_entity': createEntity,
    'create_mapper': createMapper,
    'model_path': modelPath,
    'entity_path': entityPath,
    'mapper_path': mapperPath,
  };
}
