import 'string_utils.dart';

class FilePaths {
  final String featureName;

  FilePaths(this.featureName);

  late final featurePath = StringUtils.toSnakeCase(featureName);

  ///Paths
  String get repository => 'lib/domain/repo/${featurePath}_repo.dart';

  String get useCase => 'lib/domain/use_cases/${featurePath}';

  static String get dataSource =>
      'lib/data/data_source/%name%_data_source.dart';

  String get repositoryImpl => 'lib/data/repo/${featurePath}_repo_impl.dart';

  static String get dataSourceImpl =>
      'lib/api/data_source/%name%_data_source_impl.dart';

  ///Imports
  String get dataSourceImplImport =>
      "import '../../data/data_source/%name%_data_source.dart';";

  String get repositoryImplImport =>
      "import '../../domain/repo/${featurePath}_repo.dart';";

  String get repositoryImplImport2 =>
      "import '../data_source/%name%_data_source.dart';";

  String get useCaseImport => "import '../repo/${featurePath}_repo.dart';";

  /// Get use case file path for a specific method
  static String useCaseFile(String methodName) {
    return 'lib/domain/use_cases/${StringUtils.toSnakeCase(methodName)}_use_case.dart';
  }

  static String dataSourceFile(String featureName, String type) {
    return dataSource.replaceAll("%name%",
        "${StringUtils.toSnakeCase(featureName)}_${StringUtils.toSnakeCase(type)}");
  }

  static String dataSourceImplFile(String featureName, String type) {
    return dataSourceImpl.replaceAll("%name%",
        "${StringUtils.toSnakeCase(featureName)}_${StringUtils.toSnakeCase(type)}");
  }
}
