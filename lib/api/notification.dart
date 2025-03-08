// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/logger.dart';

const _logger = Logger(tag: "Notification");

extension Notifications on FlutterLocalNotificationsPlugin {
  Future<bool?> init() async {
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final initializationSettingsLinux = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
      defaultIcon: AssetsLinuxIcon(
        'lib/assets/images/tailchat.png',
      ),
    );
    final initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
    );
    return await initialize(
      initializationSettings,
      onDidReceiveBackgroundNotificationResponse:
          _onDidReceiveBackgroundNotificationResponse,
      onDidReceiveNotificationResponse: (response) {
        _logger.d("received notification response $response");
      },
    );
  }

  static void _onDidReceiveBackgroundNotificationResponse(
    NotificationResponse response,
  ) {
    _logger.d("received background notification");
  }

  static const androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'TailchatAppChannel',
    'Tailchat App Notifications',
    channelDescription: 'Tailchat notifications from the user interfaces',
    importance: Importance.max,
    priority: Priority.high,
  );

  static const platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  Future<void> showNotification(int id, String title, String body) async {
    await show(id, title, body, platformChannelSpecifics);
  }
}

FlutterLocalNotificationsPlugin? _notification;
Future<void> notify(int id, String title, String body) async {
  _logger.d("notifying $title");
  await _notification?.showNotification(id, title, body);
}

Future<bool?> initNotifications() async {
  if (_notification != null) {
    _logger.i("notification has been initialized");
    return true;
  }
  final n = FlutterLocalNotificationsPlugin();
  final result = await n.init();
  if (result != null) {
    _notification = n;
    _logger.i("Notification initialization succeeded.");
  } else {
    _logger.e("Notification initialization failed.");
  }
  return result;
}
