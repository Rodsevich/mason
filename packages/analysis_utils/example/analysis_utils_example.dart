import 'package:analysis_utils/analysis.dart';

main(List<String> args) {
  args = ["example/example_child.dart"];
  var sourceAnalysis = SourceAnalysis.forFilePath(args.first);
  ClassAnalysis clazz = sourceAnalysis.classes.first;
  print("The class name is: ${clazz.name}");
  print("The fields are: " + clazz.fields.keys.join(", "));
  print("The methods are: " + clazz.methods.keys.join(", "));
  print("The constructors are: " + clazz.constructors.keys.join(", "));
  if (clazz.constructors.isNotEmpty && clazz.constructors[''] != null) {
    print(
        "  The default constructor has ${clazz.constructors[""]?.parameters?.length ?? 0}"
        " parameters:\n${clazz.constructors[""]?.parameters?.all.map((Parameter p) => p.name).join(", ")}");
  }
  if (clazz.methods['method2'] != null) {
    print(
        "The documentation for method2 is: " + clazz.methods["method2"]!.docs);
  }
  var parentClazz = clazz.superclassAnalysis;
  if (parentClazz != null) {
    print("The initial value of 'initVal' field is:"
        " ${parentClazz.fields['initVal']?.defaultValue}");
    print("The inherintance preserves even the annotations from the parent"
        "class! (it has ${parentClazz.fields["sorp"]?.metadata.length ?? 0} annotations)");
  }
}
