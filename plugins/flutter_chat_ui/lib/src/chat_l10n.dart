import 'package:flutter/material.dart';

/// Base chat l10n containing all required properties to provide localized copy.
/// Extend this class if you want to create a custom l10n.
@immutable
abstract class ChatL10n {
  /// Creates a new chat l10n based on provided copy
  const ChatL10n({
    required this.attachmentButtonAccessibilityLabel,
    required this.emptyChatPlaceholder,
    required this.fileButtonAccessibilityLabel,
    required this.inputPlaceholder,
    required this.sendButtonAccessibilityLabel,
    required this.holdToRecordLabel,
    required this.releaseToSendLabel,
    this.clickToRecordLabel = "Click to record",
    this.clickToSendLabel = "Click to send",
  });

  /// Accessibility label (hint) for the attachment button
  final String attachmentButtonAccessibilityLabel;

  /// Placeholder when there are no messages
  final String emptyChatPlaceholder;

  /// Accessibility label (hint) for the tap action on file message
  final String fileButtonAccessibilityLabel;

  /// Placeholder for the text field
  final String inputPlaceholder;

  /// Accessibility label (hint) for the send button
  final String sendButtonAccessibilityLabel;

  /// Hold to record label for voice message
  final String holdToRecordLabel;

  /// Click to record label for voice message
  final String clickToRecordLabel;

  /// Release to send label for voice message
  final String releaseToSendLabel;

  /// Click to send label for voice message
  final String clickToSendLabel;
}

/// English l10n which extends [ChatL10n]
@immutable
class ChatL10nEn extends ChatL10n {
  /// Creates English l10n. Use this constructor if you want to
  /// override only a couple of properties, otherwise create a new class
  /// which extends [ChatL10n]
  const ChatL10nEn({
    String attachmentButtonAccessibilityLabel = 'Send media',
    String emptyChatPlaceholder = 'No messages here yet',
    String fileButtonAccessibilityLabel = 'File',
    String inputPlaceholder = 'Message',
    String sendButtonAccessibilityLabel = 'Send',
    String holdToRecordLabel = "Hold to record",
    String releaseToSendLabel = "Release to send",
  }) : super(
          attachmentButtonAccessibilityLabel:
              attachmentButtonAccessibilityLabel,
          emptyChatPlaceholder: emptyChatPlaceholder,
          fileButtonAccessibilityLabel: fileButtonAccessibilityLabel,
          inputPlaceholder: inputPlaceholder,
          sendButtonAccessibilityLabel: sendButtonAccessibilityLabel,
          holdToRecordLabel: holdToRecordLabel,
          releaseToSendLabel: releaseToSendLabel,
        );
}

/// Spanish l10n which extends [ChatL10n]
@immutable
class ChatL10nEs extends ChatL10n {
  /// Creates Spanish l10n. Use this constructor if you want to
  /// override only a couple of properties, otherwise create a new class
  /// which extends [ChatL10n]
  const ChatL10nEs({
    String attachmentButtonAccessibilityLabel = 'Enviar multimedia',
    String emptyChatPlaceholder = 'Aún no hay mensajes',
    String fileButtonAccessibilityLabel = 'Archivo',
    String inputPlaceholder = 'Mensaje',
    String sendButtonAccessibilityLabel = 'Enviar',
    String holdToRecordLabel = "Hold to record",
    String releaseToSendLabel = "Release to send",
  }) : super(
          attachmentButtonAccessibilityLabel:
              attachmentButtonAccessibilityLabel,
          emptyChatPlaceholder: emptyChatPlaceholder,
          fileButtonAccessibilityLabel: fileButtonAccessibilityLabel,
          inputPlaceholder: inputPlaceholder,
          sendButtonAccessibilityLabel: sendButtonAccessibilityLabel,
          holdToRecordLabel: holdToRecordLabel,
          releaseToSendLabel: releaseToSendLabel,
        );
}

/// Korean l10n which extends [ChatL10n]
@immutable
class ChatL10nKo extends ChatL10n {
  /// Creates Korean l10n. Use this constructor if you want to
  /// override only a couple of properties, otherwise create a new class
  /// which extends [ChatL10n]
  const ChatL10nKo({
    String attachmentButtonAccessibilityLabel = '미디어 보내기',
    String emptyChatPlaceholder = '주고받은 메시지가 없습니다',
    String fileButtonAccessibilityLabel = '파일',
    String inputPlaceholder = '메시지',
    String sendButtonAccessibilityLabel = '보내기',
    String holdToRecordLabel = "Hold to record",
    String releaseToSendLabel = "Release to send",
  }) : super(
          attachmentButtonAccessibilityLabel:
              attachmentButtonAccessibilityLabel,
          emptyChatPlaceholder: emptyChatPlaceholder,
          fileButtonAccessibilityLabel: fileButtonAccessibilityLabel,
          inputPlaceholder: inputPlaceholder,
          sendButtonAccessibilityLabel: sendButtonAccessibilityLabel,
          holdToRecordLabel: holdToRecordLabel,
          releaseToSendLabel: releaseToSendLabel,
        );
}

/// Polish l10n which extends [ChatL10n]
@immutable
class ChatL10nPl extends ChatL10n {
  /// Creates Polish l10n. Use this constructor if you want to
  /// override only a couple of properties, otherwise create a new class
  /// which extends [ChatL10n]
  const ChatL10nPl({
    String attachmentButtonAccessibilityLabel = 'Wyślij multimedia',
    String emptyChatPlaceholder = 'Tu jeszcze nie ma wiadomości',
    String fileButtonAccessibilityLabel = 'Plik',
    String inputPlaceholder = 'Napisz wiadomość',
    String sendButtonAccessibilityLabel = 'Wyślij',
    String holdToRecordLabel = "Hold to record",
    String releaseToSendLabel = "Release to send",
  }) : super(
          attachmentButtonAccessibilityLabel:
              attachmentButtonAccessibilityLabel,
          emptyChatPlaceholder: emptyChatPlaceholder,
          fileButtonAccessibilityLabel: fileButtonAccessibilityLabel,
          inputPlaceholder: inputPlaceholder,
          sendButtonAccessibilityLabel: sendButtonAccessibilityLabel,
          holdToRecordLabel: holdToRecordLabel,
          releaseToSendLabel: releaseToSendLabel,
        );
}

/// Portuguese l10n which extends [ChatL10n]
@immutable
class ChatL10nPt extends ChatL10n {
  /// Creates Portuguese l10n. Use this constructor if you want to
  /// override only a couple of properties, otherwise create a new class
  /// which extends [ChatL10n]
  const ChatL10nPt({
    String attachmentButtonAccessibilityLabel = 'Envia mídia',
    String emptyChatPlaceholder = 'Ainda não há mensagens aqui',
    String fileButtonAccessibilityLabel = 'Arquivo',
    String inputPlaceholder = 'Mensagem',
    String sendButtonAccessibilityLabel = 'Enviar',
    String holdToRecordLabel = "Segure para gravar",
    String releaseToSendLabel = "Liberar para enviar",
  }) : super(
          attachmentButtonAccessibilityLabel:
              attachmentButtonAccessibilityLabel,
          emptyChatPlaceholder: emptyChatPlaceholder,
          fileButtonAccessibilityLabel: fileButtonAccessibilityLabel,
          inputPlaceholder: inputPlaceholder,
          sendButtonAccessibilityLabel: sendButtonAccessibilityLabel,
          holdToRecordLabel: holdToRecordLabel,
          releaseToSendLabel: releaseToSendLabel,
        );
}

/// Russian l10n which extends [ChatL10n]
@immutable
class ChatL10nRu extends ChatL10n {
  /// Creates Russian l10n. Use this constructor if you want to
  /// override only a couple of properties, otherwise create a new class
  /// which extends [ChatL10n]
  const ChatL10nRu({
    String attachmentButtonAccessibilityLabel = 'Отправить медиа',
    String emptyChatPlaceholder = 'Пока что у вас нет сообщений',
    String fileButtonAccessibilityLabel = 'Файл',
    String inputPlaceholder = 'Сообщение',
    String sendButtonAccessibilityLabel = 'Отправить',
    String holdToRecordLabel = "Удерживать для записи",
    String releaseToSendLabel = "Отпустить для отправки",
  }) : super(
          attachmentButtonAccessibilityLabel:
              attachmentButtonAccessibilityLabel,
          emptyChatPlaceholder: emptyChatPlaceholder,
          fileButtonAccessibilityLabel: fileButtonAccessibilityLabel,
          inputPlaceholder: inputPlaceholder,
          sendButtonAccessibilityLabel: sendButtonAccessibilityLabel,
          holdToRecordLabel: holdToRecordLabel,
          releaseToSendLabel: releaseToSendLabel,
        );
}

/// Turkish l10n which extends [ChatL10n]
@immutable
class ChatL10nTr extends ChatL10n {
  /// Creates Turkish l10n. Use this constructor if you want to
  /// override only a couple of properties, otherwise create a new class
  /// which extends [ChatL10n]
  const ChatL10nTr({
    String attachmentButtonAccessibilityLabel = 'Medya gönder',
    String emptyChatPlaceholder = 'Henüz mesaj yok',
    String fileButtonAccessibilityLabel = 'Dosya',
    String inputPlaceholder = 'Mesaj yazın',
    String sendButtonAccessibilityLabel = 'Gönder',
    String holdToRecordLabel = "Kaydetmek için basılı tutun",
    String releaseToSendLabel = "Göndermek için bırakın",
  }) : super(
          attachmentButtonAccessibilityLabel:
              attachmentButtonAccessibilityLabel,
          emptyChatPlaceholder: emptyChatPlaceholder,
          fileButtonAccessibilityLabel: fileButtonAccessibilityLabel,
          inputPlaceholder: inputPlaceholder,
          sendButtonAccessibilityLabel: sendButtonAccessibilityLabel,
          holdToRecordLabel: holdToRecordLabel,
          releaseToSendLabel: releaseToSendLabel,
        );
}

/// Ukrainian l10n which extends [ChatL10n]
@immutable
class ChatL10nUk extends ChatL10n {
  /// Creates Ukrainian l10n. Use this constructor if you want to
  /// override only a couple of properties, otherwise create a new class
  /// which extends [ChatL10n]
  const ChatL10nUk({
    String attachmentButtonAccessibilityLabel = 'Надіслати медіа',
    String emptyChatPlaceholder = 'Повідомлень ще немає',
    String fileButtonAccessibilityLabel = 'Файл',
    String inputPlaceholder = 'Повідомлення',
    String sendButtonAccessibilityLabel = 'Надіслати',
    String holdToRecordLabel = "Утримувати запис",
    String releaseToSendLabel = "Відпустити відправку",
  }) : super(
          attachmentButtonAccessibilityLabel:
              attachmentButtonAccessibilityLabel,
          emptyChatPlaceholder: emptyChatPlaceholder,
          fileButtonAccessibilityLabel: fileButtonAccessibilityLabel,
          inputPlaceholder: inputPlaceholder,
          sendButtonAccessibilityLabel: sendButtonAccessibilityLabel,
          holdToRecordLabel: holdToRecordLabel,
          releaseToSendLabel: releaseToSendLabel,
        );
}

/// Simplified Chinese l10n which extends [ChatL10n]
@immutable
class ChatL10nZhCN extends ChatL10n {
  /// Creates Simplified Chinese l10n. Use this constructor if you want to
  /// override only a couple of properties, otherwise create a new class
  /// which extends [ChatL10n]
  const ChatL10nZhCN({
    String attachmentButtonAccessibilityLabel = '发送媒体文件',
    String emptyChatPlaceholder = '暂无消息',
    String fileButtonAccessibilityLabel = '文件',
    String inputPlaceholder = '输入消息',
    String sendButtonAccessibilityLabel = '发送',
    String holdToRecordLabel = "按住 录音",
    String releaseToSendLabel = "松开 发送",
    String clickToRecordLabel = "点击 录音",
    String clickToSendLabel = "点击 发送",
  }) : super(
          attachmentButtonAccessibilityLabel:
              attachmentButtonAccessibilityLabel,
          emptyChatPlaceholder: emptyChatPlaceholder,
          fileButtonAccessibilityLabel: fileButtonAccessibilityLabel,
          inputPlaceholder: inputPlaceholder,
          sendButtonAccessibilityLabel: sendButtonAccessibilityLabel,
          holdToRecordLabel: holdToRecordLabel,
          releaseToSendLabel: releaseToSendLabel,
          clickToRecordLabel: clickToRecordLabel,
          clickToSendLabel: clickToSendLabel,
        );
}

/// Traditional Chinese l10n which extends [ChatL10n]
@immutable
class ChatL10nZhHant extends ChatL10n {
  /// Creates Simplified Chinese l10n. Use this constructor if you want to
  /// override only a couple of properties, otherwise create a new class
  /// which extends [ChatL10n]
  const ChatL10nZhHant({
    String attachmentButtonAccessibilityLabel = '發送媒體文件',
    String emptyChatPlaceholder = '暫無消息',
    String fileButtonAccessibilityLabel = '文件',
    String inputPlaceholder = '輸入消息',
    String sendButtonAccessibilityLabel = '發送',
    String holdToRecordLabel = "按住 錄音",
    String releaseToSendLabel = "鬆開 發送",
    String clickToRecordLabel = "点击 錄音",
    String clickToSendLabel = "点击 發送",
  }) : super(
          attachmentButtonAccessibilityLabel:
              attachmentButtonAccessibilityLabel,
          emptyChatPlaceholder: emptyChatPlaceholder,
          fileButtonAccessibilityLabel: fileButtonAccessibilityLabel,
          inputPlaceholder: inputPlaceholder,
          sendButtonAccessibilityLabel: sendButtonAccessibilityLabel,
          holdToRecordLabel: holdToRecordLabel,
          releaseToSendLabel: releaseToSendLabel,
          clickToRecordLabel: clickToRecordLabel,
          clickToSendLabel: clickToSendLabel,
        );
}
