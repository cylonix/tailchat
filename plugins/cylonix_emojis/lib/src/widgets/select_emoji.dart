import 'dart:io';
import 'package:flutter/material.dart';
import '../models/emoji.dart';
import '../models/emoji_list.dart';
import '../models/recent_emoji.dart';
import '../utils.dart';

class SelectEmoji extends StatefulWidget {
  final Function({required String code, required String asset})? onSelected;
  final Function()? onBackspacePressed;
  const SelectEmoji({
    Key? key,
    this.onBackspacePressed,
    this.onSelected,
  }) : super(key: key);
  @override
  _SelectEmojiState createState() => _SelectEmojiState();
}

class _SelectEmojiState extends State<SelectEmoji> {
  List<RecentEmoji> _recent = [];

  @override
  void initState() {
    super.initState();
    _loadRecentEmojis();
  }

  void _loadRecentEmojis() async {
    _recent = await getRecentEmojis();
    if (_recent.isNotEmpty) {
      setState(() {});
    }
  }

  Widget _emoji(Emoji e, {bool fromRecent = false}) {
    return IconButton(
      onPressed: () async {
        widget.onSelected?.call(code: e.code, asset: e.assetPath);
        _recent = await addEmojiToRecentlyUsed(e);
        if (mounted && !fromRecent) {
          setState(() {});
        }
      },
      icon: Image.asset(e.assetPath, height: 32),
    );
  }

  List<Widget> get _allEmojis {
    final emojiIcons = <Widget>[];
    for (var element in emojis) {
      emojiIcons.add(_emoji(element));
    }
    return emojiIcons;
  }

  List<Widget> get _recentEmojis {
    final emojiIcons = <Widget>[];
    for (var r in _recent) {
      emojiIcons.add(_emoji(r.emoji, fromRecent: true));
    }
    return emojiIcons;
  }

  double get _areaHeight {
    return (Platform.isAndroid || Platform.isIOS) ? 200 : 300;
  }

  double get _recentBoxHeight {
    return _areaHeight / 3;
  }

  double get _fullBoxHeight {
    return _recent.isNotEmpty ? _areaHeight / 3 * 2 : _areaHeight;
  }

  int get _gridCount {
    final w = MediaQuery.of(context).size.width;
    return (w / 50).round();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
          height: _areaHeight + 20,
          child: ListView(
            shrinkWrap: true,
            controller: ScrollController(),
            children: [
              if (_recent.isNotEmpty)
                SizedBox(
                  height: _recentBoxHeight,
                  child: GridView.count(
                    shrinkWrap: true,
                    controller: ScrollController(),
                    crossAxisCount: _gridCount,
                    children: _recentEmojis,
                  ),
                ),
              if (_recent.isNotEmpty) const Divider(height: 1),
              SizedBox(
                height: _fullBoxHeight,
                child: GridView.count(
                  controller: ScrollController(),
                  crossAxisCount: _gridCount,
                  children: _allEmojis,
                ),
              ),
            ],
          )),
    );
  }
}
