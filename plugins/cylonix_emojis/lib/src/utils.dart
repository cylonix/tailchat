import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/emoji.dart';
import 'models/recent_emoji.dart';

/// Returns list of recently used emoji from cache
const _spKey = 'cylonix_emojis_recent';
Future<List<RecentEmoji>> getRecentEmojis() async {
  final prefs = await SharedPreferences.getInstance();
  var emojiJson = prefs.getString(_spKey);
  if (emojiJson == null) {
    return [];
  }
  var json = jsonDecode(emojiJson) as List<dynamic>;
  return json.map<RecentEmoji>(RecentEmoji.fromJson).toList();
}

/// Add an emoji to recently used list or increase its counter
Future<List<RecentEmoji>> addEmojiToRecentlyUsed(Emoji emoji) async {
  var recentEmoji = await getRecentEmojis();
  final index = recentEmoji.indexWhere(
    (element) => element.emoji.code == emoji.code,
  );

  if (index != -1) {
    recentEmoji[index].counter++;
  } else if (recentEmoji.length == 8) {
    recentEmoji[recentEmoji.length - 1] = RecentEmoji(emoji, 1);
  } else {
    recentEmoji.add(RecentEmoji(emoji, 1));
  }

  recentEmoji.sort((a, b) => b.counter - a.counter);
  recentEmoji = recentEmoji.sublist(0, min(8, recentEmoji.length));
  final prefs = await SharedPreferences.getInstance();
  prefs.setString(_spKey, jsonEncode(recentEmoji));

  return recentEmoji;
}
