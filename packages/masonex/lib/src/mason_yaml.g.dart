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
      git: json['git'] == null ? null : GitPath.fromJson(json['git']),
      version: json['version'] as String?,
    );

Map<String, dynamic> _$BrickLocationToJson(BrickLocation instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('path', instance.path);
  writeNotNull('git', instance.git?.toJson());
  writeNotNull('version', instance.version);
  return val;
}

GitPath _$GitPathFromJson(Map json) => GitPath(
      json['url'] as String,
      path: json['path'] as String?,
      ref: json['ref'] as String?,
    );

Map<String, dynamic> _$GitPathToJson(GitPath instance) {
  final val = <String, dynamic>{
    'url': instance.url,
    'path': instance.path,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('ref', instance.ref);
  return val;
}
