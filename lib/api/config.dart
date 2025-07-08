// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import "dart:convert";
import 'dart:io';
import 'dart:ui';
import 'package:event_bus/event_bus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../gen/l10n/app_localizations.dart';
import '../models/chat/chat_event.dart';
import '../models/config/config_change_event.dart';
import '../models/contacts/device.dart';
import '../models/contacts/user_profile.dart';
import "../utils/global.dart";
import "../utils/logger.dart";

final _logger = Logger(tag: "config");

String companyName() {
  return "EZBLOCK INC";
}

String contactEmail() {
  return "contact@cylonix.io";
}

String copyrightText(AppLocalizations tr) {
  return tr.copyright(companyName());
}

String? getEnv(String key) {
  try {
    return dotenv.maybeGet(key);
  } catch (e) {
    // Ignored.
  }
  return null;
}

bool get enableAR {
  return enableARByDefault;
}

bool get enableTV {
  return enableTVByDefault;
}

bool get enableARByDefault {
  return Global.isARDevice;
}

bool get enableTVByDefault {
  return Global.isAndroidTV;
}

String? get officialSupportUrl {
  return "https://cylonix.io/web/view/product/tailchat.html";
}

String? get androidAppLink {
  return "https://play.google.com/store/apps/details?id=io.cylonix.tailchat&pcampaignid=web_share";
}

String get appName {
  return "Tailchat";
}

String? get iosAppLink {
  return "https://testflight.apple.com/join/7eWmjBBJ";
}

class Pst {
  // Persistent shared preference
  static const _spAutoAcceptVideo = "auto_accept_video";
  static const _spChatSimpleUI = "chat_simple_ui";
  static const _spDevice = "device";
  static const _spEnableAR = "enable_ar";
  static const _spEnableTV = "enable_tv";
  static const _spPushNotificationUUID = "push_notification_uuid";
  static const _spPushNotificationToken = "push_notification_token";
  static const _spQrData = "qr_data";
  static const _spSkipIntro = "skip_intro";
  static const _spThemeIndex = "theme_index";
  static const _spUserProfile = "user_profile";
  static const _spWindowHeight = 'window_height';
  static const _spWindowWidth = "window_width";

  static bool? autoAcceptVideo;
  static bool? chatSimpleUI;
  static bool configLoaded = false;
  static bool? enableAR;
  static bool? enableTV;
  static final eventBus = EventBus();
  static String? pushNotificationUUID;
  static String? pushNotificationToken;
  static String? qrData;
  static Device? selfDevice;
  static UserProfile? selfUser;
  static String? serverUrl;
  static bool? skipIntro;
  static int? themeIndex;
  static Size? windowSize;
  static bool windowSizeLoaded = false;

  static Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    T tryCatch<T>(T Function(SharedPreferences) f) {
      try {
        return f(sp);
      } catch (e) {
        final msg = "failed to load $f: $e";
        _logger.e(msg);
        throw msg;
      }
    }

    try {
      // Keep simple preferences to the top and json decode error prone
      // ones to the bottom. Try to keep alphabetical orders too.
      autoAcceptVideo = tryCatch(_getSavedVideoSetting);
      chatSimpleUI = tryCatch(_getSavedChatSimpleUISetting);
      enableAR = tryCatch(_getSavedEnableAR);
      enableTV = tryCatch(_getSavedEnableTV);
      pushNotificationUUID = tryCatch(_getSavedPushNotificationUUID);
      skipIntro = tryCatch(_getSavedSkipIntro);
      themeIndex = tryCatch(_getSavedThemeIndex);
      qrData = tryCatch(_getSavedQrData);
      windowSize = tryCatch(_getSavedWindowSize);

      selfDevice = tryCatch(_getSavedSelfDevice);
      selfUser = tryCatch(_getSavedSelfUser);
    } catch (e) {
      final msg = "failed to get saved configs: $e";
      _logger.e(msg);
      throw Exception(msg);
    } finally {
      configLoaded = true;
      eventBus.fire(ConfigLoadedEvent());
    }
  }

  static String? get namespace {
    return null;
  }

  // Individual key/value api's
  static Future<String?> getStringWithKey(String key) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(key);
  }

  static Future<bool> setStringWithKey(String key, String str) async {
    final sp = await SharedPreferences.getInstance();
    return sp.setString(key, str);
  }

  static Future<bool?> getBoolWithKey(String key) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(key);
  }

  static Future<bool> setBoolWithKey(String key, bool val) async {
    final sp = await SharedPreferences.getInstance();
    return sp.setBool(key, val);
  }

  static Future<int?> getIntWithKey(String key) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(key);
  }

  static Future<bool> setIntWithKey(String key, int val) async {
    final sp = await SharedPreferences.getInstance();
    return sp.setInt(key, val);
  }

  static Future<bool> setDoubleWithKey(String key, double val) async {
    final sp = await SharedPreferences.getInstance();
    return sp.setDouble(key, val);
  }

  static Future<bool> removeWithKey(String key) async {
    final sp = await SharedPreferences.getInstance();
    return sp.remove(key);
  }

  /// Get saved chat simple UI setting
  static bool? _getSavedChatSimpleUISetting(SharedPreferences sp) {
    return sp.getBool(_spChatSimpleUI);
  }

  static Future<bool?> getSavedChatSimpleUISetting() async {
    final sp = await SharedPreferences.getInstance();
    return _getSavedChatSimpleUISetting(sp);
  }

  static Future<bool> saveChatSimpleUISetting(bool enable) async {
    chatSimpleUI = enable;
    eventBus.fire(ChatSimpleUISettingChangeEvent(enable: enable));
    final sp = await SharedPreferences.getInstance();
    return sp.setBool(_spChatSimpleUI, enable);
  }

  static Future<bool> removeSavedChatSimpleUISetting() async {
    chatSimpleUI = null;
    return removeWithKey(_spChatSimpleUI);
  }

  static Device? _getSavedSelfDevice(SharedPreferences sp) {
    final str = sp.getString(_spDevice);
    if (str != null) {
      return Device.fromJson(jsonDecode(str));
    }
    return null;
  }

  static Future<Device?> getSavedSelfDevice() async {
    final sp = await SharedPreferences.getInstance();
    return _getSavedSelfDevice(sp);
  }

  static Future<bool> saveSelfDevice(Device? device) async {
    Pst.selfDevice = device;
    eventBus.fire(SelfDeviceChangeEvent(newDevice: device));
    return setStringWithKey(_spDevice, jsonEncode(device?.toJson()));
  }

  static Future<bool> removeSavedSelfDevice() async {
    Pst.selfDevice = null;
    eventBus.fire(SelfDeviceChangeEvent());
    return removeWithKey(_spDevice);
  }

  static bool isSelfDevice(String? id) {
    return selfDevice?.id == id;
  }

  static bool? _getSavedEnableAR(SharedPreferences sp) {
    final value = sp.getBool(_spEnableAR);
    // Handle if getting the default value the first time.
    if (value == null && enableARByDefault) {
      setBoolWithKey(_spEnableAR, true);
      return true;
    }
    return value;
  }

  /// Get saved enable AR
  static Future<bool?> getSavedEnableAR() async {
    final sp = await SharedPreferences.getInstance();
    return _getSavedEnableAR(sp);
  }

  /// Set enable AR
  static Future<bool> saveEnableAR(bool set) async {
    enableAR = set;
    eventBus.fire(EnableAREvent(enable: set));
    return setBoolWithKey(_spEnableAR, set);
  }

  /// Del enable AR
  static Future<bool> removeSavedEnableAR() async {
    return removeWithKey(_spEnableAR);
  }

  static bool? _getSavedEnableTV(SharedPreferences sp) {
    final value = sp.getBool(_spEnableTV);
    // Handle if getting the default value the first time.
    if (value == null && enableTVByDefault) {
      setBoolWithKey(_spEnableTV, true);
      return true;
    }
    return value;
  }

  /// Get saved enable TV
  static Future<bool?> getSavedEnableTV() async {
    final sp = await SharedPreferences.getInstance();
    return _getSavedEnableTV(sp);
  }

  /// Set enable TV
  static Future<bool> saveEnableTV(bool set) async {
    enableTV = set;
    eventBus.fire(EnableTVEvent(enable: set));
    return setBoolWithKey(_spEnableTV, set);
  }

  /// Del enable TV
  static Future<bool> removeSavedEnableTV() async {
    return removeWithKey(_spEnableTV);
  }

  static Future<String?> getSavedPushNotificationUUID() async {
    final sp = await SharedPreferences.getInstance();
    return _getSavedPushNotificationUUID(sp);
  }

  static String? _getSavedPushNotificationUUID(SharedPreferences sp) {
    return sp.getString(_spPushNotificationUUID);
  }

  static Future<bool> savePushNotificationUUID(String uuid) async {
    pushNotificationUUID = uuid;
    return setStringWithKey(_spPushNotificationUUID, uuid);
  }

  static Future<bool> removeSavedPushNoitificationUUID() async {
    pushNotificationUUID = null;
    return removeWithKey(_spPushNotificationUUID);
  }

  static Future<String?> getSavedPushNotificationToken() async {
    final sp = await SharedPreferences.getInstance();
    return _getSavedPushNotificationToken(sp);
  }

  static String? _getSavedPushNotificationToken(SharedPreferences sp) {
    return sp.getString(_spPushNotificationToken);
  }

  static Future<bool> savePushNotificationToken(String token) async {
    pushNotificationToken = token;
    return setStringWithKey(_spPushNotificationToken, token);
  }

  static Future<bool> removeSavedPushNoitificationToken() async {
    pushNotificationToken = null;
    return removeWithKey(_spPushNotificationToken);
  }

  /// Get saved user/self qr data
  /// Note it throws an exception if there is no valid data saved.
  static Future<String?> getSavedQrData() async {
    final sp = await SharedPreferences.getInstance();
    return _getSavedQrData(sp);
  }

  static String? _getSavedQrData(SharedPreferences sp) {
    return sp.getString(_spQrData);
  }

  /// Set saved user qr data
  static Future<bool> saveQrData(String qrData) async {
    qrData = qrData;
    return setStringWithKey(_spQrData, qrData);
  }

  /// Remove saved user qr data
  static Future<bool> removeSavedQrData() async {
    qrData = null;
    return removeWithKey(_spQrData);
  }

  /// Saved self user profile
  static Future<UserProfile?> getSavedSelfUser() async {
    final sp = await SharedPreferences.getInstance();
    return _getSavedSelfUser(sp);
  }

  static UserProfile? _getSavedSelfUser(SharedPreferences sp) {
    final str = sp.getString(_spUserProfile);
    if (str != null) {
      return UserProfile.fromJson(jsonDecode(str));
    }
    return null;
  }

  static Future<bool> saveSelfUser(UserProfile? user) {
    selfUser = user;
    if (user == null) {
      _logger.d("remove self user");
      return removeSavedSelfUser();
    }
    eventBus.fire(SelfUserChangeEvent(newSelfUser: user));
    return setStringWithKey(_spUserProfile, jsonEncode(user.toJson()));
  }

  static Future<bool> removeSavedSelfUser() async {
    selfUser = null;
    eventBus.fire(SelfUserChangeEvent());
    return removeWithKey(_spUserProfile);
  }

  static bool isSelfUser(String? id) {
    return selfUser?.id == id;
  }

  /// Get saved skip-intro
  static Future<bool?> getSavedSkipIntro() async {
    final sp = await SharedPreferences.getInstance();
    return _getSavedSkipIntro(sp);
  }

  static bool? _getSavedSkipIntro(SharedPreferences sp) {
    return sp.getBool(_spSkipIntro);
  }

  /// Set skip-intro
  static Future<bool> saveSkipIntro(bool skip) async {
    skipIntro = skip;
    return setBoolWithKey(_spSkipIntro, skip);
  }

  /// Del skip-intro
  static Future<bool> removeSavedSkipIntro() async {
    skipIntro = null;
    return removeWithKey(_spSkipIntro);
  }

  /// Get saved theme index
  static Future<int?> getSavedThemeIndex() async {
    final sp = await SharedPreferences.getInstance();
    return _getSavedThemeIndex(sp);
  }

  static int? _getSavedThemeIndex(SharedPreferences sp) {
    return sp.getInt(_spThemeIndex);
  }

  /// Set theme index
  static Future<bool> saveThemeIndex(int idx) async {
    themeIndex = idx;
    return setIntWithKey(_spThemeIndex, idx);
  }

  /// Del theme index
  static Future<bool> removeSavedThemeIndex() async {
    themeIndex = null;
    return removeWithKey(_spThemeIndex);
  }

  /// Get saved auto accept video meeting setting
  static Future<bool?> getSavedVideoSetting() async {
    final sp = await SharedPreferences.getInstance();
    return _getSavedVideoSetting(sp);
  }

  static bool? _getSavedVideoSetting(SharedPreferences sp) {
    return sp.getBool(_spAutoAcceptVideo);
  }

  /// Set auto accept video meeting setting
  static Future<bool> saveVideoAutoAcceptSetting(bool val) async {
    autoAcceptVideo = val;
    return setBoolWithKey(_spAutoAcceptVideo, val);
  }

  /// Del auto accept video meeting setting
  static Future<bool> removeSavedVideoSetting() async {
    autoAcceptVideo = null;
    return removeWithKey(_spAutoAcceptVideo);
  }

  /// Get saved window size
  static Size? _getSavedWindowSize(SharedPreferences sp) {
    final h = sp.getDouble(_spWindowHeight);
    final w = sp.getDouble(_spWindowWidth);
    _logger.d("loaded saved window size $w x $h");
    windowSizeLoaded = true;
    if (h != null && w != null) {
      return Size(w, h);
    }
    return null;
  }

  /// Remove saved window size
  static Future<bool> removeSavedWindowSize() async {
    windowSize = null;
    return await removeWithKey(_spWindowHeight) &&
        await removeWithKey(_spWindowWidth);
  }

  /// Save window size
  static Future<bool> saveWindowSize(Size size) async {
    if (Platform.isAndroid || Platform.isIOS) {
      return true;
    }
    final s = Size(size.width.roundToDouble(), size.height.roundToDouble());
    if (windowSize == s || !windowSizeLoaded) {
      return true;
    }
    windowSize = s;
    return await setDoubleWithKey(_spWindowHeight, s.height) &&
        await setDoubleWithKey(_spWindowWidth, s.width);
  }
}
