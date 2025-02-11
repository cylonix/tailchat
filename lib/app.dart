// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:overlay_support/overlay_support.dart';

import 'gen/l10n/app_localizations.dart';
import 'home_page.dart';
import 'models/chat/chat_session.dart';
import 'models/delete_session_notifier.dart';
import 'models/new_session_notifier.dart';
import 'models/theme_change_event.dart';
import 'utils/utils.dart';
import 'utils/global.dart';
import 'widgets/chat/chat_page.dart';
import 'widgets/main_bottom_bar.dart';
import 'widgets/theme.dart';

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BottomBarSelection()),
        ChangeNotifierProvider(create: (_) => BottomBarSessionNoticeCount()),
        ChangeNotifierProvider(create: (_) => BottomBarContactNotice()),
        ChangeNotifierProvider(create: (_) => NewSessionNotifier()),
        ChangeNotifierProvider(create: (_) => DeleteSessionNotifier()),
      ],
      child: _App(key: key),
    );
  }
}

class _App extends StatefulWidget {
  const _App({super.key});
  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  ThemeData _themeData = themeList[0];
  StreamSubscription<ThemeChangeEvent>? _themeChangeSub;
  double? _textScaleFactor;

  @override
  void initState() {
    super.initState();
    _registerThemeEvent();
  }

  void _registerThemeEvent() {
    final eventBus = Global.getThemeEventBus();
    _themeChangeSub = eventBus.on<ThemeChangeEvent>().listen((onData) {
      setState(() {
        final scale = onData.textScaleFactor;
        if (scale != null) {
          _textScaleFactor = (_textScaleFactor ?? 1.0) * scale;
        }
        final themeIndex = onData.themeIndex;
        if (themeIndex != null) {
          _themeData = themeList[themeIndex];
        }
      });
    });
  }

  @override
  void dispose() {
    _themeChangeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OverlaySupport.global(
      child: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        },
        child: _app,
      ),
    );
  }

  Widget get _app {
    return MaterialApp(
      builder: (context, child) {
        if (isXLargeScreen(context)) {
          _textScaleFactor ??= 1.3;
        }
        if (_textScaleFactor == null) {
          return child ?? Container();
        }
        final MediaQueryData data = MediaQuery.of(context);
        return MediaQuery(
          data: data.copyWith(
            textScaler: _textScaleFactor != null
                ? TextScaler.linear(_textScaleFactor!)
                : null,
          ),
          child: child ?? Container(),
        );
      },
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: _themeData,
      supportedLocales: AppLocalizations.supportedLocales,
      routes: <String, WidgetBuilder>{
        '/': (BuildContext context) {
          return const HomePage();
        },
      },
      navigatorObservers: [Global.routeObserver],
      navigatorKey: Global.navigatorKey,
      onGenerateRoute: (settings) {
        if (settings.name?.startsWith('/chat/') ?? false) {
          final session = ChatSession.fromJson(
            settings.arguments as Map<String, dynamic>,
          );
          return MaterialPageRoute(
            builder: (context) => ChatPage(
              key: Key(session.sessionID),
              session: session,
            ),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}
