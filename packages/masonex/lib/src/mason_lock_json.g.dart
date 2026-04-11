// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mason_lock_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MasonexLockJson _$MasonexLockJsonFromJson(Map json) => MasonexLockJson(
  bricks: (json['bricks'] as Map?)?.map(
    (k, e) => MapEntry(k as String, BrickLocation.fromJson(e)),
  ),
);

Map<String, dynamic> _$MasonexLockJsonToJson(MasonexLockJson instance) =>
    <String, dynamic>{'bricks': instance.bricks};
