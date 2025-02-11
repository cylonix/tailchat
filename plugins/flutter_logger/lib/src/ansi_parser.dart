import 'package:flutter/material.dart';

enum TextType {
  text,
  bracket,
  code,
}
class AnsiParser {
  final bool dark;

  AnsiParser(this.dark) {
    background = Colors.transparent;
    foreground = dark ? Colors.white : Colors.black;
  }

  late Color foreground;
  late Color background;
  List<TextSpan> spans = [];

  void parse(String s) {
    spans = [];
    var state = TextType.text;
    var buffer = StringBuffer();
    var text = StringBuffer();
    var code = 0;
    List<int> codes = [];

    for (var i = 0, n = s.length; i < n; i++) {
      var c = s[i];

      switch (state) {
        case TextType.text:
          if (c == '\u001b') {
            state = TextType.bracket;
            buffer = StringBuffer(c);
            code = 0;
            codes = [];
          } else {
            text.write(c);
          }
          break;

        case TextType.bracket:
          buffer.write(c);
          if (c == '[') {
            state = TextType.code;
          } else {
            state = TextType.text;
            text.write(buffer);
          }
          break;

        case TextType.code:
          buffer.write(c);
          var codeUnit = c.codeUnitAt(0);
          if (codeUnit >= 48 && codeUnit <= 57) {
            code = code * 10 + codeUnit - 48;
            continue;
          } else if (c == ';') {
            codes.add(code);
            code = 0;
            continue;
          } else {
            if (text.isNotEmpty) {
              spans.add(createSpan(text.toString()));
              text.clear();
            }
            state = TextType.text;
            if (c == 'm') {
              codes.add(code);
              handleCodes(codes);
            } else {
              text.write(buffer);
            }
          }

          break;
      }
    }

    spans.add(createSpan(text.toString()));
  }

  void handleCodes(List<int> codes) {
    if (codes.isEmpty) {
      codes.add(0);
    }

    switch (codes[0]) {
      case 0:
        foreground = getColor(0, true);
        background = getColor(0, false);
        break;
      case 38:
        foreground = getColor(codes[2], true);
        break;
      case 39:
        foreground = getColor(0, true);
        break;
      case 48:
        background = getColor(codes[2], false);
        break;
      case 49:
        background = getColor(0, false);
    }
  }

  Color getColor(int colorCode, bool foreground) {
    switch (colorCode) {
      case 12:
        return dark ? Colors.lightBlue[300]! : Colors.indigo[700]!;
      case 208:
        return dark ? Colors.orange[300]! : Colors.orange[700]!;
      case 196:
        return dark ? Colors.red[300]! : Colors.red[700]!;
      case 199:
        return dark ? Colors.pink[300]! : Colors.pink[700]!;
      default:
        return foreground ? Colors.black : Colors.transparent;
    }
  }

  TextSpan createSpan(String text) {
    return TextSpan(
      text: text,
      style: TextStyle(
        color: foreground,
        backgroundColor: background,
      ),
    );
  }
}
