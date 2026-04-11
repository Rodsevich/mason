// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mason_bundle.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MasonexBundledFile _$MasonexBundledFileFromJson(Map<String, dynamic> json) =>
    MasonexBundledFile(
      json['path'] as String,
      json['data'] as String,
      json['type'] as String,
    );

Map<String, dynamic> _$MasonexBundledFileToJson(MasonexBundledFile instance) =>
    <String, dynamic>{
      'path': instance.path,
      'data': instance.data,
      'type': instance.type,
    };

MasonexBundle _$MasonexBundleFromJson(
  Map<String, dynamic> json,
) => MasonexBundle(
  name: json['name'] as String,
  description: json['description'] as String,
  version: json['version'] as String,
  environment: json['environment'] == null
      ? const BrickEnvironment()
      : BrickEnvironment.fromJson(json['environment']),
  vars: json['vars'] == null
      ? const <String, BrickVariableProperties>{}
      : const VarsConverter().fromJson(json['vars']),
  files:
      (json['files'] as List<dynamic>?)
          ?.map((e) => MasonexBundledFile.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  hooks:
      (json['hooks'] as List<dynamic>?)
          ?.map((e) => MasonexBundledFile.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  repository: json['repository'] as String?,
  publishTo: json['publish_to'] as String?,
  readme: json['readme'] == null
      ? null
      : MasonexBundledFile.fromJson(json['readme'] as Map<String, dynamic>),
  changelog: json['changelog'] == null
      ? null
      : MasonexBundledFile.fromJson(json['changelog'] as Map<String, dynamic>),
  license: json['license'] == null
      ? null
      : MasonexBundledFile.fromJson(json['license'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MasonexBundleToJson(MasonexBundle instance) =>
    <String, dynamic>{
      'files': instance.files,
      'hooks': instance.hooks,
      'name': instance.name,
      'description': instance.description,
      'version': instance.version,
      'environment': instance.environment,
      'repository': instance.repository,
      'publish_to': instance.publishTo,
      'readme': instance.readme,
      'changelog': instance.changelog,
      'license': instance.license,
      'vars': const VarsConverter().toJson(instance.vars),
    };
