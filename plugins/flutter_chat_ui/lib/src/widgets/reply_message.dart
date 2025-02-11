import 'package:cylonix_emojis/cylonix_emojis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'image_message.dart';
import 'inherited_chat_theme.dart';

/// A class that represents reply message widget.
class ReplyMessage extends StatefulWidget {
  const ReplyMessage({
    Key? key,
    required this.message,
    this.onClosed,
    this.shrinkWrap = false,
    this.uriFixup,
  }) : super(key: key);

  /// [types.Message]
  final types.Message message;

  /// Handler when the reply message widget is closed.
  final void Function()? onClosed;

  /// Expand or not.
  final bool shrinkWrap;

  /// Fix URI for file/image messages.
  final Future<String?> Function(String?)? uriFixup;

  @override
  _ReplyMessageState createState() => _ReplyMessageState();
}

/// [ReplyMessage] widget state
class _ReplyMessageState extends State<ReplyMessage> {
  @override
  Widget build(BuildContext context) {
    final query = MediaQuery.of(context);
    final theme = InheritedChatTheme.of(context).theme;
    final children = <Widget>[
      Text('${widget.message.author.firstName ?? ""}: '),
    ];
    children.addAll(_summary);

    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryColor,
      ),
      padding: EdgeInsets.fromLTRB(
        24 + query.padding.left,
        10,
        24 + query.padding.right,
        10,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.reply_outlined),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: children,
              ),
            ),
            fit: widget.shrinkWrap ? FlexFit.loose : FlexFit.tight,
          ),
          if (widget.onClosed != null) CloseButton(onPressed: widget.onClosed!),
        ],
      ),
    );
  }

  List<Widget> get _summary {
    final theme = InheritedChatTheme.of(context).theme;
    final message = widget.message;
    if (message is types.EmojiMessage) {
      final summary = message.shortText;
      final list = summary.codeUnits.map((e) {
        final asset = lookupByCode(e)?.assetPath;
        return asset == null ? const SizedBox() : Image.asset(asset, width: 16);
      }).toList();
      return list;
    } else if (message is types.ImageMessage) {
      return [
        ImageMessage(
          message: message,
          uriFixup: widget.uriFixup,
          showSummaryFormat: true,
        ),
      ];
    } else if (message is types.FileMessage) {
      return [
        theme.documentIcon != null
            ? theme.documentIcon!
            : Image.asset(
                'assets/icon-document.png',
                package: 'flutter_chat_ui',
              ),
        Text(message.shortName, textWidthBasis: TextWidthBasis.longestLine),
      ];
    }
    return [Text(message.summary, textWidthBasis: TextWidthBasis.longestLine)];
  }
}
