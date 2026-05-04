import 'package:build/build.dart';
import 'package:masonex/src/builders/in_file_generation_builder.dart';

/// Returns a [Builder] that performs in-file generation for masonex bricks.
Builder inFileGenerationBuilder(BuilderOptions options) =>
    InFileGenerationBuilder();
