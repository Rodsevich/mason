# build_utils

A package with a bunch of classes, helpers, generators and things to work with [package:build](https://pub.dev/packages/build) with ease

## Builders

Abstract classes of builders that contains a function to override that should return the output of the file given by parameter:

### BuilderMISO

A Builder with _Multiple Input, Single Output_ strategy that produces its output through calling the following function:

```dart
FutureOr<String> buildOutput(Set<AssetId> inputs);
```
In there you should process the _inputs_ for obtaining the _Single Output_ which contents will be returned by the function.

### BuilderMIMO

A Builder with _Multiple Input, Multiple Output_ strategy that produces
 its _Multiple Outputs_ by calling the following function once per output provided
```dart
FutureOr<String> buildOutputFor(String outputPath, Set<AssetId> inputs);
```
where **outputPath** will contain the path of the file being generated in the call to the function and _inputs_ will be the same as with MISO builders

## Analyzer builders

As an extension for the above mentioned builders, the Analyzer Builders include in their functions a second one for performing the analysis of the code with the [analyzer](https://pub.dev/packages/analyzer) package. The function to implement is this:
```dart
FutureOr<Map> analysisResultsFor(
      AssetId asset, LibraryElement library, Resolver resolver);
```
In there you should generate a map containing the data you need from the analysis done of the **asset** provided with the **library** and **resolver** derived of it. It will be used later in the respective function for building.

### BuilderAnalyzerMISO

The analyzer equivalent of the MISOBuilder which function is the following:
```dart
FutureOr<String> buildOutputWithAnalysis(Map<AssetId, Map> inputsWithAnalysis);
```
In there you should process the _inputWithAnalysis_ (a map with the input assets matched with their respective previously analyzed) for obtaining the _Single Output_ which contents will be the returned by the function.

### BuilderAnalyzerMIMO

This is the same as with the above builder except that the function will be called once for every output, which path will be provided by parameter.
```dart
FutureOr<String> buildOutputWithAnalysisFor(
      String outputPath, Map<AssetId, Map> inputsWithAnalysis);
```

## source_gen

This package also provides helpers for the [source_gen](https://pub.dev/packages/source_gen) package

### ClassPartGenerator

It's an abstract class that should be instantiated with a fuction for checking if the part file should be generated or not. That function should follow this type:
```dart
typedef ShouldGenerateForFuction = bool Function(ClassElement element);
```
In case it returns true the implementation of the following function will be run:

```dart
FutureOr<String> partCode(ClassElement element);
```
and the output will be the source of the part file generated.

As an example, a part generator that finds private classes and creates a part file of them with the comment of the class found should be like this:

```dart
class ExampleClassPartGenerator extends ClassPartGenerator {
  ExampleClassPartGenerator(ShouldGenerateForFuction checkingFn)
      : super(checkingFunction: checkingFn);

  @override
  FutureOr<String> partCode(ClassElement element) {
    return '//Found class: ${element.name}';
  }
}

// The file of this function may/should be referenced by build.yaml
Builder exampleBuilder() {
  ShouldGenerateForFunction fn;
  fn = (e) => e.isPrivate;
  return PartBuilder([ExampleClassPartGenerator(fn)], '.g.dart');
}

```