// import 'dart:mirrors';
// import 'package:analyzer/dart/ast/ast.dart';

// import './expression_handler.dart';

// /// Instnatiate from an analyzer's package's [Annotation] (must provide the type,
// /// however)
// dynamic instanceFromAnnotation(Type annotationType, Annotation annotation) =>
//     instantiate(annotationType, annotation.constructorName ?? '',
//         ArgumentsResolution.fromArgumentList(annotation.arguments));

// dynamic instantiate(Type type, constructorName, ArgumentsResolution arguments) {
//   ClassMirror annotationMirror = reflectClass(type);
//   return annotationMirror
//       .newInstance(
//           (constructorName is Symbol)
//               ? constructorName
//               : Symbol(constructorName),
//           arguments.positional,
//           arguments.named)
//       .reflectee;
// }
