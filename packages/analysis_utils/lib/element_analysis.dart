/// util functions for working with Element model analysis
library element_analysis;

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';

/// Gets all the [FieldElement]s of the given [ClassElement]
Set<FieldElement> getAllFields(ClassElement clazz) {
  var visitor = _Visitor();
  return visitor.getFieldsFor(clazz);
}

/// Gets all the [MethodElement]s of the given [ClassElement]
Set<MethodElement> getAllMethods(ClassElement clazz) {
  var visitor = _Visitor();
  return visitor.getMethodsFor(clazz);
}

class _Visitor extends GeneralizingElementVisitor {
  Set<FieldElement> _fields = {};
  Set<MethodElement> _methods = {};

  Set<FieldElement> getFieldsFor(ClassElement clazz) {
    _fields = {};
    clazz.accept(this);
    clazz.allSupertypes.map((t) => t.element).forEach((st) {
      st.accept(this);
    });
    return _fields;
  }

  Set<MethodElement> getMethodsFor(ClassElement clazz) {
    _methods = {};
    clazz.accept(this);
    clazz.allSupertypes.map((t) => t.element).forEach((st) {
      st.accept(this);
    });
    return _methods;
  }

  @override
  visitFieldElement(FieldElement element) {
    _fields.add(element);
    return super.visitFieldElement(element);
  }

  @override
  visitMethodElement(MethodElement element) {
    _methods.add(element);
    return super.visitMethodElement(element);
  }
}
