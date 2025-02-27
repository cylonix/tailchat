import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

enum TextType {
  text,
  bracket,
  code,
}

class AnsiParser {
  final bool dark;

  AnsiParser(this.dark, {Level? level}) {
    background = Colors.transparent;
    foreground = dark ? Colors.white : Colors.black;
    setDefault(level);
  }

  late Color foreground;
  late Color background;
  List<TextSpan> spans = [];

  void setDefault(Level? level) {
    if (level == null) {
      return;
    }

    switch (level) {
      case Level.error: // Red foreground
        foreground = dark ? Colors.red[300]! : Colors.red[700]!;
        break;
      case Level.warning: // Yellow foreground
        foreground = dark ? Colors.yellow[300]! : Colors.yellow[700]!;
        break;
      case Level.info: // Blue foreground
        foreground = dark ? Colors.blue[300]! : Colors.blue[700]!;
        break;
      default:
        break;
    }
  }

  void parse(String s, {Color? color}) {
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
              handleCodesOrig(codes, color: color);
            } else {
              text.write(buffer);
            }
          }

          break;
      }
    }

    spans.add(createSpan(text.toString()));
  }

  void handleCodes(List<int> codes, {Color? color}) {
    if (codes.isEmpty) {
      codes.add(0);
    }

    for (var i = 0; i < codes.length; i++) {
      switch (codes[i]) {
        case 0: // Reset
          foreground = dark ? Colors.white : Colors.black;
          background = Colors.transparent;
          break;
        case 30: // Black foreground
          foreground = dark ? Colors.grey[300]! : Colors.black;
          break;
        case 31: // Red foreground
          foreground = dark ? Colors.red[300]! : Colors.red[700]!;
          break;
        case 32: // Green foreground
          foreground = dark ? Colors.green[300]! : Colors.green[700]!;
          break;
        case 33: // Yellow foreground
          foreground = dark ? Colors.yellow[300]! : Colors.yellow[700]!;
          break;
        case 34: // Blue foreground
          foreground = dark ? Colors.blue[300]! : Colors.blue[700]!;
          break;
        case 35: // Magenta foreground
          foreground = dark ? Colors.purple[300]! : Colors.purple[700]!;
          break;
        case 36: // Cyan foreground
          foreground = dark ? Colors.cyan[300]! : Colors.cyan[700]!;
          break;
        case 37: // White foreground
          foreground = dark ? Colors.white : Colors.grey[800]!;
          break;
        case 39: // Default foreground
          foreground = dark ? Colors.white : Colors.black;
          break;
        case 90: // Bright Black foreground
          foreground = dark ? Colors.grey[400]! : Colors.grey[700]!;
          break;
        case 91: // Bright Red foreground
          foreground = dark ? Colors.red[400]! : Colors.red[600]!;
          break;
        case 92: // Bright Green foreground
          foreground = dark ? Colors.green[400]! : Colors.green[600]!;
          break;
        case 93: // Bright Yellow foreground
          foreground = dark ? Colors.yellow[400]! : Colors.yellow[600]!;
          break;
        case 94: // Bright Blue foreground
          foreground = dark ? Colors.blue[400]! : Colors.blue[600]!;
          break;
        case 95: // Bright Magenta foreground
          foreground = dark ? Colors.purple[400]! : Colors.purple[600]!;
          break;
        case 96: // Bright Cyan foreground
          foreground = dark ? Colors.cyan[400]! : Colors.cyan[600]!;
          break;
        case 97: // Bright White foreground
          foreground = dark ? Colors.white : Colors.grey[600]!;
          break;
      }
    }

    // Override with custom color if provided
    if (color != null) {
      foreground = color;
    }
  }

  void handleCodesOrig(List<int> codes, {Color? color}) {
    if (codes.isEmpty) {
      codes.add(0);
    }

    switch (codes[0]) {
      case 0:
        foreground = getColor(0, true, color: color);
        background = getColor(0, false);
        break;
      case 38:
        foreground = getColor(codes[2], true, color: color);
        break;
      case 39:
        foreground = getColor(0, true, color: color);
        break;
      case 48:
        background = getColor(codes[2], false);
        break;
      case 49:
        background = getColor(0, false);
    }
  }

  Color getColor(int colorCode, bool foreground, {Color? color}) {
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
        return foreground ? color ?? Colors.black : Colors.transparent;
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
