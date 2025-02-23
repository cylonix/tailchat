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
  CupertinoColors.activeOrange,
  CupertinoColors.lightBackgroundGray,
  CupertinoColors.systemCyan,
  CupertinoColors.systemTeal,
  CupertinoColors.systemGrey2,
];

const appleDarkThemeIconBackgroundColors = [
  CupertinoColors.activeBlue,
  CupertinoColors.darkBackgroundGray,
  CupertinoColors.systemCyan,
  CupertinoColors.systemTeal,
  CupertinoColors.systemGrey,
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
        height: size ?? 24,
        width: size ?? 24,
        child: Icon(icon, color: color, size: size != null ? size - 8 : 16),
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

Widget getOsIcon(String os, {Color? color, double? size}) {
  switch (os) {
    case "android":
      return Icon(Icons.android, size: size, color: color);
    case "ios":
      return Icon(Icons.phone_iphone, size: size, color: color);
    case "linux":
      // TODO: check finer details among varies distros.
      return FaIcon(FontAwesomeIcons.linux, size: size, color: color);
    case "macos":
      return Icon(Icons.laptop_mac, size: size, color: color);
    case "windows":
      return Icon(Icons.laptop_windows, size: size, color: color);
    default:
      return Icon(Icons.devices, size: size, color: color);
  }
}

Widget loadingWidget() {
  return const Center(child: CircularProgressIndicator());
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
