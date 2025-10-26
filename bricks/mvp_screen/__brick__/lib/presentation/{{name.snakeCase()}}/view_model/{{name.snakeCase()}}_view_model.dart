import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '{{name.snakeCase()}}_events.dart';

part '{{name.snakeCase()}}_state.dart';

@injectable
class {{name.pascalCase()}}ViewModel extends Cubit<{{name.pascalCase()}}State> {
  {{name.pascalCase()}}ViewModel() : super(const {{name.pascalCase()}}State());

  void doIntent({{name.pascalCase()}}Events events) {
    switch (events) {
      case {{name.pascalCase()}}Event():
      // TODO: Handle this case.
        throw UnimplementedError();
    }
  }
}