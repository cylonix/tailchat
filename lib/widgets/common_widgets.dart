// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/utils.dart';

/// Shows a red error icon and a message
Widget getErrorWidget(String error) {
  return Column(
    children: <Widget>[
      const Icon(Icons.error_outline, color: Colors.red, size: 60),
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(error),
      )
    ],
  );
}

/// Common app bar
AppBar getAppBar(BuildContext context, String title) {
  return AppBar(
    elevation: 0.0,
    title: Text(title),
    centerTitle: true,
  );
}
const appleLightThemeIconBackgroundColors = [
  CupertinoColors.systemGreen, // Fresh green
  CupertinoColors.systemOrange, // Warm orange
  CupertinoColors.systemPink, // Vibrant pink
  CupertinoColors.systemPurple, // Royal purple
  CupertinoColors.systemTeal, // Cool teal
  Color(0xFFE9F3FF), // Light blue
  Color(0xFFE8FCE9), // Light mint
  Color(0xFFFFF3E0), // Light orange
];

const appleDarkThemeIconBackgroundColors = [
  CupertinoColors.activeBlue, // Vivid blue
  CupertinoColors.systemPurple, // Bright purple
  CupertinoColors.systemPink, // Deep pink
  CupertinoColors.systemIndigo, // Deep indigo
  CupertinoColors.systemTeal, // Deep teal
  Color(0xFF1C4A7E), // Dark navy
  Color(0xFF1E4D3E), // Dark forest
  Color(0xFF4A3123), // Dark burgundy
];

/// Common icon style
Widget getIcon(
  IconData icon, {
  Color? color,
  double? size,
  bool darkTheme = false,
  bool adaptive = true,
  Color? appleBackgroundColor,
}) {
  if (isApple() && adaptive) {
    final set = darkTheme
        ? appleDarkThemeIconBackgroundColors
        : appleLightThemeIconBackgroundColors;
    final colorIndex = icon.hashCode % set.length;
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(4),
      color: appleBackgroundColor ?? set[colorIndex],
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: (size ?? 24) + 8,
        width: (size ?? 24) + 8,
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
  return Icon(icon, color: color, size: size);
}

Widget getLogoImageArea() {
  const logo = "packages/sase_app_ui/assets/images/logo.png";
  return Center(
    heightFactor: 1.5,
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Image.asset(logo, width: 120, height: 100),
    ]),
  );
}

/// OS logo with online/offline colors
Widget getOsOnlineIcon(String os, bool online, {double? size}) {
  final onlineColor = online ? Colors.green : Colors.grey;
  return getOsIcon(os.toLowerCase(), color: onlineColor, size: size);
}

IconData getOsIconData(String os) {
  switch (os) {
    case "android":
      return Icons.android;
    case "ios":
      return Icons.phone_iphone;
    case "linux":
      return FontAwesomeIcons.linux;
    case "macos":
      return Icons.laptop_mac;
    case "windows":
      return Icons.laptop_windows;
    default:
      return Icons.devices;
  }
}

Widget getOsIcon(String os, {Color? color, double? size}) {
  return getIcon(getOsIconData(os), color: color, size: size, adaptive: false);
}

Widget loadingWidget() {
  return Center(
    child: CircularProgressIndicator.adaptive(padding: const EdgeInsets.all(4)),
  );
}

ShapeBorder commonShapeBorder() {
  return RoundedRectangleBorder(borderRadius: commonBorderRadius());
}

BorderRadius commonBorderRadius() {
  return BorderRadius.circular(16.0);
}

RelativeRect? getShowMenuPosition(
  BuildContext context,
  Offset? savedPosition, {
  Offset offset = Offset.zero,
}) {
  final overlay = Overlay.of(context).context.findRenderObject();
  if (overlay == null) {
    return null;
  }
  return RelativeRect.fromRect(
    (savedPosition ?? Offset.zero) & const Size(40, 40),
    offset & overlay.semanticBounds.size,
  );
}

ShapeBorder focusAwareCircleBorder(BuildContext context, FocusNode? focus) {
  return CircleBorder(
    side: (focus?.hasFocus ?? false)
        ? BorderSide(color: focusColor(context), width: 2)
        : BorderSide.none,
  );
}

double focusAwareSize(BuildContext context, FocusNode? focus, double size,
    {double? zoom}) {
  return (focus?.hasFocus ?? false) ? size * (zoom ?? 1.2) : size;
}

ShapeBorder focusAwareShapeBorder(ShapeBorder shape, FocusNode? focus) {
  return (focus?.hasFocus ?? false) ? shape.scale(1.2) : shape;
}

BorderSide focusAwareBorderSide(BorderSide border, FocusNode? focus) {
  return (focus?.hasFocus ?? false)
      ? const BorderSide(color: Colors.blue, width: 4)
      : border;
}

BoxDecoration focusAwareDecoration(BoxDecoration decoration, FocusNode? focus) {
  return (focus?.hasFocus ?? false)
      ? decoration.copyWith(
          border: Border.all(color: Colors.blue, width: 4),
        )
      : decoration;
}

class OnlineStatusIcon extends Icon {
  const OnlineStatusIcon(bool isOnline, {Key? key})
      : super(
          Icons.online_prediction_rounded,
          key: key,
          color: isOnline ? Colors.green : Colors.grey,
        );
}
