part of '{{name.snakeCase()}}_view_model.dart';

final class {{name.pascalCase()}}State extends Equatable {
  final bool isLoading;
  final String? errorMessage;

  const {{name.pascalCase()}}State({
    this.isLoading = false,
    this.errorMessage,
  });

{{name.pascalCase()}}State copyWith({
    bool? isLoading,
    String? errorMessage,
  }) {
    return {{name.pascalCase()}}State(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [isLoading, errorMessage];
}