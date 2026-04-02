import 'example_parent.dart';

/// The classic documentation
/// comment is supported
class ExampleClass extends ParentClass {
  /** Also
   * this
   * kind
   * of
   * documentation
   * is
   * supported
   */
  int field1;
  String? field2;

  void method1() {
    print("method1 executed");
  }

  /// Greet `name` sopongo
  String method2(String name) => "Hello $name";

  ExampleClass(String param1, int param2, [this.field1 = 1]);

  ExampleClass.withField2(this.field2) : field1 = 2;
}
