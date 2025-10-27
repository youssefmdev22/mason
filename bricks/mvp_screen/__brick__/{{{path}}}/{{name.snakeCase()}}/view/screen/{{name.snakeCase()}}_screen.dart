import 'package:flutter/material.dart';

import '../../../../../core/di/di.dart';
import '../../view_model/{{name.snakeCase()}}_view_model.dart';

class {{name.pascalCase()}}Screen extends StatefulWidget {
  const {{name.pascalCase()}}Screen({super.key});

  @override
  State<{{name.pascalCase()}}Screen> createState() => _{{name.pascalCase()}}ScreenState();
}

class _{{name.pascalCase()}}ScreenState extends State<{{name.pascalCase()}}Screen> {
  late final {{name.pascalCase()}}ViewModel {{name.camelCase()}}ViewModel;

  @override
  void initState() {
    super.initState();
    {{name.camelCase()}}ViewModel = getIt<{{name.pascalCase()}}ViewModel>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold();
  }
}