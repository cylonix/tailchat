// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:random_color/random_color.dart';

import '../api/config.dart';
import '../gen/l10n/app_localizations.dart';
import '../widgets/alert_dialog_widget.dart' as ad;
import 'global.dart';

const double baseHeight = 480;
const double baseWidth = 1080;
const List<String> imageExtensions = ['jpg', 'png', 'jpeg', 'gif'];
const String replaceableText = "file://";
double screenAwareSize(double size, BuildContext context) {
  return size * MediaQuery.of(context).size.height / baseHeight;
}

double screenAwareSizeWidth(double size, BuildContext context) {
  return size * MediaQuery.of(context).size.width / baseWidth;
}

bool isXLargeScreen(BuildContext context) {
  return MediaQuery.of(context).size.width > 1920.0;
}

bool isLargeScreen(BuildContext context) {
  return MediaQuery.of(context).size.width > 960.0;
}

bool isMediumScreen(BuildContext context) {
  return MediaQuery.of(context).size.width > 640.0;
}

bool useNavigationRail(BuildContext context) {
  return isMediumScreen(context);
}

bool isInPortraitMode(BuildContext context) {
  return MediaQuery.of(context).orientation == Orientation.portrait;
}

bool useTVTopNavigationRail(BuildContext context) {
  return (Pst.enableTV ?? false) &&
      useNavigationRail(context) &&
      isInPortraitMode(context);
}

bool preferOutlinedMenuAnchorButton() {
  return !enableMaterial3() || !(Pst.enableTV ?? false);
}

bool preferOnOffButtonOverSwitch() {
  return Pst.enableAR ?? false;
}

/// MenuAnchor still has issues on not being able to auto-focus when open in TV
/// mode. Prefer popup menu instead for now.
bool preferPopupMenuButton() {
  return Pst.enableTV ?? false;
}

/// Prefer full width popup menu entry due to inability to detect tap down
/// positions.
bool preferPopupMenuItemExpanded() {
  return Pst.enableTV ?? false;
}

bool preferNamespaceTabBarInAppBar() {
  return !(Pst.enableTV ?? false);
}

Offset getPopupMenuOffset() {
  return Pst.enableTV ?? false ? const Offset(0, -100) : const Offset(0, 0);
}

Future<bool?> showAlertDialog(
  BuildContext context,
  String title,
  String content, {
  String? okText,
  List<ad.Content> contents = const [],
  List<ad.Action> actions = const [],
}) {
  return ad.AlertDialogWidget(
    title: title,
    contents: [
      ad.Content(content: content),
      ...contents,
    ],
    actions: [
      ad.Action(
        title: okText ?? AppLocalizations.of(context).ok,
        onPressed: () {
          Navigator.of(context).pop(true);
        },
      ),
      ...actions,
    ],
  ).show(context);
}

bool isDarkMode(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}

Color focusColor(BuildContext context) {
  return Theme.of(context).colorScheme.inversePrimary;
}

TextStyle? smallTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w300,
      );
}

TextStyle? titleLargeTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.titleLarge?.apply(
        color: Theme.of(context).colorScheme.secondary,
        fontWeightDelta: 3,
      );
}

TextStyle? titleMediumTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.titleMedium?.apply(
        color: Theme.of(context).colorScheme.secondary,
        fontWeightDelta: 3,
      );
}

bool enableMaterial3() {
  // Support material3 can be a per-platform choice.
  // Enable for all platforms for now and can be reverted back if necessary.
  return true;
}

bool isMobile() {
  return Platform.isAndroid || Platform.isIOS;
}

bool isApple() {
  return Platform.isMacOS || Platform.isIOS;
}

Future<bool> isAndroidTV() async {
  if (!Platform.isAndroid) {
    return false;
  }
  final deviceInfo = DeviceInfoPlugin();
  final androidInfo = await deviceInfo.androidInfo;
  return androidInfo.systemFeatures.contains('android.software.leanback');
}

Future<String?> deviceInfoDetail() async {
  if (!Platform.isAndroid) {
    return null;
  }
  final deviceInfo = DeviceInfoPlugin();
  final a = await deviceInfo.androidInfo;
  return "${a.manufacturer} ${a.brand} ${a.product} ${a.model}";
}

/// Check if it is an AR device.
const _arDeviceManufacturerList = [
  'RealWear inc.',
];
const _arDarkModeDeviceManufacturerList = [
  'RealWear inc.',
];
String _manufacturer = "";
Future<bool> isARDevice() async {
  if (!Platform.isAndroid) {
    return false;
  }
  final deviceInfo = DeviceInfoPlugin();
  final a = await deviceInfo.androidInfo;
  _manufacturer = a.manufacturer;
  final isAR = _arDeviceManufacturerList.contains(_manufacturer);
  Global.logger.d("Manufacturer='$_manufacturer' isAR=$isAR");
  return isAR;
}

/// If device is HiAR.
bool isHiARDevice() {
  return _manufacturer == 'HiAR';
}

/// If to set default to dark mode.
bool isDartModeARDevice() {
  return _arDarkModeDeviceManufacturerList.contains(_manufacturer);
}

/// If possibly a TV box that is on by default.
const _canBeAndroidTVDeviceManufacturerList = [
  'rockchip',
];
bool canBeAndroidTV() {
  return _canBeAndroidTVDeviceManufacturerList.contains(_manufacturer);
}

bool isDesktop() {
  return !isMobile();
}

String timeFormat(String time) {
  String date = '';
  if (time.isNotEmpty) {
    var dateTime = DateFormat("yyyy-MM-ddTHH:mm:ssZ").parse(time, true);
    if (dateTime.year != 1) {
      date = dateTime.toString();
      date = date.split(".").first;
    }
  }
  return date;
}

String formatBytes(int bytes, int decimals) {
  if (bytes <= 0) return "";
  const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
  var i = (log(bytes) / log(1024)).floor();
  return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
}

// Verify namespace
String? validateNamespace(BuildContext context, String? value) {
  final tr = AppLocalizations.of(context);
  if (value == null || value.isEmpty) {
    return tr.namespaceEmpty;
  }
  // todo: Further validations:
  return null;
}

/// Validate username
String? validateUsername(BuildContext? context, String? value,
    {AppLocalizations? tr}) {
  tr ??= AppLocalizations.of(context!);
  if (value == null || value.isEmpty) {
    return tr.usernameEmpty;
  }

  value = value.trim();
  if (value.length < 4 || value.length > 100) {
    return tr.goodUsernameText;
  }
  return null;
}

const _loginPageRouteName = "/login";
bool isOnLoginPage(BuildContext context) {
  bool isCurrent = false;
  Navigator.maybeOf(context)?.popUntil((route) {
    Global.logger.d("route setting=${route.settings}");
    final currentName = route.settings.name;
    if (currentName == _loginPageRouteName) {
      isCurrent = true;
    }
    Global.logger.d("current name is $currentName");
    // Stop popping
    return true;
  });
  return isCurrent;
}

/// Default function to check if file exists
Future<bool> _fileExists(String path) async {
  return await File(path).exists();
}

/// Try to make file as '{filename} (i).ext" with up to 10 or make it as
/// {filename}_{unix sec}.ext
Future<String> makeSureFileNotExists(
  String path, {
  Future<bool> Function(String path) exists = _fileExists,
}) async {
  final s = path.split(".");
  late String name, ext;
  if (s.length >= 2) {
    ext = '.${s.last}';
    name = path.substring(0, path.length - ext.length);
  } else {
    name = path;
    ext = "";
  }
  for (int i = 1; i <= 10; i++) {
    if (await exists(path)) {
      path = '$name ($i)$ext';
    } else {
      return path;
    }
  }
  final ts = DateTime.now().millisecondsSinceEpoch;
  return "${name}_$ts$ext";
}

/// ShowBySide base on the screen size
bool showSideBySide(BuildContext context) {
  final screenSize = MediaQuery.of(context).size;
  return (screenSize.width > 1200);
}

extension DateTimePlus on DateTime {
  static get zero {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

extension StringPlus on String {
  /// Returns a substring with a max size that can be larger than length.
  shortString(int max, {int start = 0}) {
    if (start >= length) {
      return "";
    }
    if (start + max >= length) {
      return substring(start);
    }
    return substring(start, start + max);
  }

  /// Short string that can handle multi-byte codes.
  shortRunes(int max, {int start = 0}) {
    if (runes.length >= max + start) {
      return this;
    }
    return String.fromCharCodes(runes.toList().sublist(start, max));
  }

  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }

  /// Returns a substring with protocol prefix like 'https://' removed.
  protocolPrefixRemoved() {
    return replaceFirst(RegExp('^.*://'), '');
  }
}

bool isVideo(String path) {
  final mimeType = lookupMimeType(path);
  return mimeType?.startsWith('video/') ?? false;
}

bool isImage(String path) {
  final mimeType = lookupMimeType(path);
  return mimeType?.startsWith('image/') ?? false;
}

Color getRandomColor(bool isDarkTheme, {int? seed}) {
  return RandomColor(seed).randomColor(
    colorBrightness: isDarkTheme ? ColorBrightness.dark : ColorBrightness.light,
    colorSaturation: ColorSaturation.highSaturation,
    colorHue: ColorHue.multiple(colorHues: [
      ColorHue.green,
      ColorHue.blue,
      ColorHue.purple,
    ]),
  );
}

void switchToDefaultHomePage(BuildContext context) {
  Navigator.of(context).popUntil(ModalRoute.withName('/'));
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.center,
      ),
    ),
  );
}
