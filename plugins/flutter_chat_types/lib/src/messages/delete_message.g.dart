// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeleteMessage _$DeleteMessageFromJson(Map<String, dynamic> json) =>
    DeleteMessage(
      author: User.fromJson(json['author'] as Map<String, dynamic>),
      createdAt: (json['createdAt'] as num?)?.toInt(),
      id: json['id'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
      remoteId: json['remoteId'] as String?,
      roomId: json['roomId'] as String?,
      caption: json['caption'] as String?,
      status: $enumDecodeNullable(_$StatusEnumMap, json['status']),
      replyId: json['replyId'] as String?,
      type: $enumDecodeNullable(_$MessageTypeEnumMap, json['type']),
      updatedAt: (json['updatedAt'] as num?)?.toInt(),
      deleteAll: json['deleteAll'] as bool? ?? false,
      summary: json['summary'] as String? ?? "",
    );

Map<String, dynamic> _$DeleteMessageToJson(DeleteMessage instance) {
  final val = <String, dynamic>{
    'author': instance.author.toJson(),
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('createdAt', instance.createdAt);
  val['id'] = instance.id;
  writeNotNull('metadata', instance.metadata);
  writeNotNull('remoteId', instance.remoteId);
  writeNotNull('roomId', instance.roomId);
  writeNotNull('caption', instance.caption);
  writeNotNull('status', _$StatusEnumMap[instance.status]);
  val['type'] = _$MessageTypeEnumMap[instance.type]!;
  writeNotNull('updatedAt', instance.updatedAt);
  writeNotNull('replyId', instance.replyId);
  val['deleteAll'] = instance.deleteAll;
  val['summary'] = instance.summary;
  return val;
}

const _$StatusEnumMap = {
  Status.delivered: 'delivered',
  Status.error: 'error',
  Status.seen: 'seen',
  Status.sending: 'sending',
  Status.toretry: 'toretry',
  Status.retrying: 'retrying',
  Status.sent: 'sent',
  Status.received: 'received',
  Status.paused: 'paused',
};

const _$MessageTypeEnumMap = {
  MessageType.custom: 'custom',
  MessageType.delete: 'delete',
  MessageType.emoji: 'emoji',
  MessageType.file: 'file',
  MessageType.image: 'image',
  MessageType.text: 'text',
  MessageType.unsupported: 'unsupported',
};
