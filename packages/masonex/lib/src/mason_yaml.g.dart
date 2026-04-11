// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mason_yaml.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MasonexYaml _$MasonexYamlFromJson(Map json) => MasonexYaml(
  (json['bricks'] as Map?)?.map(
    (k, e) => MapEntry(k as String, BrickLocation.fromJson(e)),
  ),
);

Map<String, dynamic> _$MasonexYamlToJson(MasonexYaml instance) =>
    <String, dynamic>{
      'bricks': instance.bricks.map((k, e) => MapEntry(k, e.toJson())),
    };

BrickLocation _$BrickLocationFromJson(Map json) => BrickLocation(
  path: json['path'] as String?,
  git: json['git'] == null ? null : GitPath.fromJson(json['git'] as Map),
  version: json['version'] as String?,
);

Map<String, dynamic> _$BrickLocationToJson(BrickLocation instance) =>
    <String, dynamic>{
      'path': instance.path,
      'git': instance.git?.toJson(),
      'version': instance.version,
    };

GitPath _$GitPathFromJson(Map json) => GitPath(
  json['url'] as String,
  path: json['path'] as String?,
  ref: json['ref'] as String?,
);

Map<String, dynamic> _$GitPathToJson(GitPath instance) => <String, dynamic>{
  'url': instance.url,
  'path': instance.path,
  'ref': instance.ref,
};
