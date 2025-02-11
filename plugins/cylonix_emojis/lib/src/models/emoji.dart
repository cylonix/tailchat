// https://en.wikipedia.org/wiki/Unicode#Code_planes_and_blocks
// "Private-use code points are considered to be assigned characters, but they
// have no interpretation specified by the Unicode standard[65] so any
// interchange of such characters requires an agreement between sender
// and receiver on their interpretation. There are three private-use areas
// in the Unicode codespace:
//   - Private Use Area: U+E000–U+F8FF (6,400 characters),
//   - Supplementary Private Use Area-A: U+F0000–U+FFFFD (65,534 characters),
//   - Supplementary Private Use Area-B: U+100000–U+10FFFD (65,534 characters).

// To add more emojis from assets. Add the asset to the public.yaml to be
// included in the package.

class Emoji {
  final String code;
  final String name;
  final String asset;
  Emoji(this.code, this.name, this.asset);
  factory Emoji.fromJson(Map<String, dynamic> json) {
    return Emoji(json['code'], json['name'], json['asset']);
  }
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'code': code,
      'name': name,
      'asset': asset,
    };
  }

  String get assetPath {
    return 'packages/cylonix_emojis/assets/$asset';
  }
}
