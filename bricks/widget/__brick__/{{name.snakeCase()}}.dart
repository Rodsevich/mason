@pragma('masonex:header', {
  MyWidget: '{{name.pascalCase()}}',
})
library;

import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}
