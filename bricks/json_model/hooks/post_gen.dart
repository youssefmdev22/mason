import 'package:mason/mason.dart';

import 'src/generators/entity_generator.dart';
import 'src/generators/mapper_generator.dart';
import 'src/generators/model_generator.dart';
import 'src/models/generation_config.dart';
import 'src/parsers/json_parser.dart';

void run(HookContext context) {
  final logger = context.logger;

  try {
    // 1. Parse configuration
    final config = GenerationConfig.fromContext(context);

    // 2. Read and parse JSON
    final jsonData = JsonParser.parseFromFile('json_gen.json', logger);
    if (jsonData == null) return;

    // 3. Generate Model
    final modelResult = ModelGenerator.generate(
      config: config,
      jsonData: jsonData,
      logger: logger,
    );

    // 4. Generate Entity (if needed)
    if (config.createEntity) {
      EntityGenerator.generate(
        config: config,
        jsonData: jsonData,
        nestedClasses: modelResult.nestedClasses,
        logger: logger,
      );
    }

    // 5. Generate Mapper (if needed)
    if (config.createMapper) {
      MapperGenerator.generate(
        config: config,
        jsonData: jsonData,
        nestedClasses: modelResult.nestedClasses,
        modelFilePath: modelResult.filePath,
        logger: logger,
      );
    }

    logger.success('Generation completed successfully!');
  } catch (e) {
    logger.err('Generation failed: $e');
  }
}
