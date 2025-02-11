// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ImageMessage _$ImageMessageFromJson(Map<String, dynamic> json) => ImageMessage(
      author: User.fromJson(json['author'] as Map<String, dynamic>),
      createdAt: (json['createdAt'] as num?)?.toInt(),
      expireAt: (json['expireAt'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toDouble(),
      id: json['id'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
      name: json['name'] as String,
      remoteId: json['remoteId'] as String?,
      roomId: json['roomId'] as String?,
      caption: json['caption'] as String?,
      replyId: json['replyId'] as String?,
      size: json['size'] as num,
      status: $enumDecodeNullable(_$StatusEnumMap, json['status']),
      percentage: (json['percentage'] as num?)?.toDouble(),
      type: $enumDecodeNullable(_$MessageTypeEnumMap, json['type']),
      updatedAt: (json['updatedAt'] as num?)?.toInt(),
      uri: json['uri'] as String,
      width: (json['width'] as num?)?.toDouble(),
      isEmoji: json['isEmoji'] as bool? ?? false,
    );

Map<String, dynamic> _$ImageMessageToJson(ImageMessage instance) {
  final val = <String, dynamic>{
    'author': instance.author.toJson(),
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('createdAt', instance.createdAt);
  writeNotNull('expireAt', instance.expireAt);
  val['id'] = instance.id;
  writeNotNull('metadata', instance.metadata);
  writeNotNull('remoteId', instance.remoteId);
  writeNotNull('roomId', instance.roomId);
  writeNotNull('caption', instance.caption);
  writeNotNull('status', _$StatusEnumMap[instance.status]);
  val['type'] = _$MessageTypeEnumMap[instance.type]!;
  writeNotNull('updatedAt', instance.updatedAt);
  writeNotNull('replyId', instance.replyId);
  val['isEmoji'] = instance.isEmoji;
  writeNotNull('height', instance.height);
  val['name'] = instance.name;
  val['size'] = instance.size;
  val['uri'] = instance.uri;
  writeNotNull('width', instance.width);
  writeNotNull('percentage', instance.percentage);
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
