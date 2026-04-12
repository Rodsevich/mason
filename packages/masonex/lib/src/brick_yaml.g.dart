// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brick_yaml.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrickYaml _$BrickYamlFromJson(Map json) => BrickYaml(
      name: json['name'] as String,
      description: json['description'] as String,
      version: json['version'] as String,
      publishTo: json['publish_to'] as String?,
      environment: json['environment'] == null
          ? const BrickEnvironment()
          : const BrickEnvironmentConverter().fromJson(json['environment']),
      vars: json['vars'] == null
          ? const <String, BrickVariableProperties>{}
          : const VarsConverter().fromJson(json['vars']),
      inFileGenerations: (json['in_file_generations'] as Map?)?.map(
            (k, e) => MapEntry(k as String, Map<String, String>.from(e as Map)),
          ) ??
          const <String, Map<String, String>>{},
      repository: json['repository'] as String?,
      path: json['path'] as String?,
    );

Map<String, dynamic> _$BrickYamlToJson(BrickYaml instance) => <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'version': instance.version,
      'environment':
          const BrickEnvironmentConverter().toJson(instance.environment),
      'repository': instance.repository,
      'publish_to': instance.publishTo,
      'vars': const VarsConverter().toJson(instance.vars),
      'in_file_generations': instance.inFileGenerations,
      'path': instance.path,
    };

BrickVariableProperties _$BrickVariablePropertiesFromJson(Map json) =>
    BrickVariableProperties(
      type: $enumDecode(_$BrickVariableTypeEnumMap, json['type']),
      description: json['description'] as String?,
      defaultValue: json['default'],
      defaultValues: json['defaults'],
      prompt: json['prompt'] as String?,
      values:
          (json['values'] as List<dynamic>?)?.map((e) => e as String).toList(),
      separator: json['separator'] as String?,
    );

Map<String, dynamic> _$BrickVariablePropertiesToJson(
        BrickVariableProperties instance) =>
    <String, dynamic>{
      'type': _$BrickVariableTypeEnumMap[instance.type]!,
      'description': instance.description,
      'default': instance.defaultValue,
      'defaults': instance.defaultValues,
      'prompt': instance.prompt,
      'values': instance.values,
      'separator': instance.separator,
    };

const _$BrickVariableTypeEnumMap = {
  BrickVariableType.array: 'array',
  BrickVariableType.number: 'number',
  BrickVariableType.string: 'string',
  BrickVariableType.boolean: 'boolean',
  BrickVariableType.enumeration: 'enum',
  BrickVariableType.list: 'list',
};

BrickEnvironment _$BrickEnvironmentFromJson(Map json) => BrickEnvironment(
      masonex: json['masonex'] as String? ?? 'any',
    );

Map<String, dynamic> _$BrickEnvironmentToJson(BrickEnvironment instance) =>
    <String, dynamic>{
      'masonex': instance.masonex,
    };
