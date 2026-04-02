/// A library with common builders to use them with ease
library build_utils;

// Para hacer los mixins sin tanto espamento
export 'package:build_utils/src/common.dart';

// Para ahorrar el tener q importar el build también (tal
// vez sea mala práctica, pero q la chupe)
export 'package:build/build.dart';

export 'src/builders/miso.dart';
export 'src/builders/mimo.dart';
export 'src/builders/analyzer_miso.dart';
export 'src/builders/analyzer_mimo.dart';
export 'src/builders/analyzer_auxiliar.dart';
export 'src/source_gen/class_part_generator.dart';

export 'src/misc.dart';
