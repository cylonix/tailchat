// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';

// Please keep imports in alphabetical order
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

// From the same package
import 'api/api.dart' as api;
import 'api/chat_server.dart';
import 'api/config.dart';
import 'api/contacts.dart';
import 'api/notification.dart';
import 'contacts_page.dart';
import 'first_launch_page.dart';
import 'gen/l10n/app_localizations.dart';
import 'models/alert.dart';
import 'models/config/config_change_event.dart';
import 'models/theme_change_event.dart';
import 'receive_share_page.dart';
import 'sessions_page.dart';
import 'theme_page.dart';
import 'utils/global.dart';
import 'utils/logger.dart';
import 'utils/utils.dart';
import 'widgets/alert_chip.dart';
import 'widgets/common_widgets.dart';
import 'widgets/contacts/contact_details_page.dart';
import 'widgets/contacts/network_monitor.dart';
import 'widgets/main_app_bar.dart';
import 'widgets/main_button.dart';
import 'widgets/main_drawer.dart';
import 'widgets/main_bottom_bar.dart';
import 'widgets/main_navigation_rail.dart';
import 'widgets/setting/account_and_settings_page.dart';
import 'widgets/snackbar_widget.dart';
import 'widgets/stack_with.dart';
import 'widgets/will_pop_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver, RouteAware {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  var _isLoading = false;
  var _enableAR = false;
  var _enableTV = false;
  Alert? _alert;

  static final _logger = Logger(tag: "Home");

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<List<SharedMediaFile>>? _shareMediaFileSub;
  StreamSubscription<String>? _shareTextSub;
  StreamSubscription<ConfigChangeEvent>? _configChangeSub;
  Timer? _connectivityCheckTimer;
  bool _isNetworkAvailable = true;
  late PageController _pageController;
  late final BottomBarSelection _selectPageNotifier;
  late final _buildStartCompleter = Completer<bool>();
  final localNotifications = FlutterLocalNotificationsPlugin();
  Widget? _rightSide;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    _logger.d("setting a new home page's states");
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _registerToSelectPageNotifier();
    _initHomePageState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Global.routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  /// For desktop side-by-side views, chat page is not pop/pushed and hence
  /// we need to clear the active chat ID whenever home page is not active.
  /// For not-side-by-side operation, this is OK as the newly pushed chat
  /// page will set its ID to be the active ID afterwards.
  @override
  void didPushNext() {
    ChatServer.clearActiveChatID();
  }

  @override
  void didPop() {
    ChatServer.clearActiveChatID();
  }

  @override
  void dispose() {
    _logger.w("disposing the home page. this is rare!");
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _shareMediaFileSub?.cancel();
    _shareTextSub?.cancel();
    _configChangeSub?.cancel();
    _connectivityCheckTimer?.cancel();
    Global.routeObserver.unsubscribe(this);
    _setLandscapeMode(false);
    _removeSelectPageNotifierListener();
    _pageController.dispose();
    super.dispose();
  }

  void _registerToSelectPageNotifier() {
    _pageController =
        PageController(initialPage: MainBottomBarPage.sessions.index);
    _selectPageNotifier = context.read<BottomBarSelection>();
    _selectPageNotifier.addListener(_selectPageListener);
  }

  void _removeSelectPageNotifierListener() {
    _selectPageNotifier.removeListener(_selectPageListener);
  }

  void _selectPageListener() {
    final index = _selectPageNotifier.getIndex();
    _selectPage(index);
  }

  void _selectPage(int index) {
    if (index < 0 || index >= MainBottomBarPage.values.length) {
      _logger.e("bad page index $index");
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _rightSide = null; // Reset right side view.
    });
    final hasClients = _pageController.hasClients;
    if (hasClients) {
      setState(() {
        _pageController.jumpToPage(index);
      });
    }
    if (index != MainBottomBar.pageIndexOf(MainBottomBarPage.sessions)) {
      ChatServer.clearActiveChatID();
    }
  }

  void _showInitErrorDialog(String title, String errMessage) {
    Future.microtask(() async {
      if (!mounted) {
        return;
      }
      await showAlertDialog(
        context,
        title,
        errMessage,
      );
    });
  }

  void _initHomePageState() async {
    _logger.d("loading configurations and saved states");
    _isLoading = true;
    await Global.init();
    try {
      await Pst.init();
    } catch (e) {
      _showInitErrorDialog("Failed to load saved states", "$e");
    }
    _enableAR = Pst.enableAR ?? enableARByDefault;
    _enableTV = Pst.enableTV ?? enableTVByDefault;
    Global.logger.d("Enable AR is $_enableAR");
    if (_enableAR) {
      _setLandscapeMode(true);
    }
    Global.initDesktopWindowSize();
    setState(() {
      _isLoading = false;
    });
    _logger.d("done loading configurations and saved states");

    final themeIndex = Pst.themeIndex ??
        ((_enableTV || Global.isDarkModeARDevice)
            ? ThemeOption.dark.index
            : null);
    if (themeIndex != null || _enableAR || _enableTV) {
      final eventBus = Global.getThemeEventBus();
      eventBus.fire(ThemeChangeEvent(
        themeIndex: themeIndex,
        textScaleFactor: _defaultTextScaleFactor,
      ));
    }

    await initNotifications();

    _logger.i("------------------ Start building home page ------------------");
    _buildStartCompleter.complete(true);

    _registerConfigChangeEvent();
    _connectivitySubscriptionInitialize();

    // Start chat server.
    try {
      ChatServer.init(_onChatServiceError, (alert) {
        if (mounted) {
          setState(() {
            _alert = alert;
          });
        }
      });
      ChatServer.startServer(_onChatServiceError);
      ChatServer.subscribeToMessages(_onChatServiceError);
    } catch (e) {
      _logger.e("Failed to start chat server: $e");
      setState(() {
        _alert = Alert("Chat service error: $e");
      });
    }

    // Check first launch.
    await checkFirstLaunch();

    // Share callbacks.
    if (isMobile()) {
      _listenShareMediaFiles();
    }
  }

  void _onChatServiceError(dynamic e) async {
    _logger.e("Chat service error: $e");
    if (mounted) {
      setState(() {
        _alert = Alert("Chat service error: $e");
      });
    }
  }

  Future<void> checkFirstLaunch() async {
    if (Pst.selfUser == null && mounted) {
      final completer = Completer();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FirstLaunchPage(
            onFirstLaunchComplete: () {
              _logger.d("first launch complete, proceeding...");
              completer.complete();
            },
          ),
        ),
      );
      await completer.future;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _logger.d("app resumed");
        ChatServer.setAppIsActive(true, _onChatServiceError);
        // Reset connectivity subs and subscribe/check connectivity.
        _connectivitySubscriptionInitialize();
        if (isMobile()) {
          _listenShareMediaFiles();
        }
        break;
      case AppLifecycleState.paused:
        _logger.d("app paused");
        ChatServer.setAppIsActive(false, _onChatServiceError);
        break;
      case AppLifecycleState.inactive:
        _logger.d("app inactive");
        break;
      case AppLifecycleState.detached:
        _logger.d("app detached");
        break;
      default:
        _logger.d("app state unknown: $state");
        break;
    }
  }

  void _setLandscapeMode(bool enable) async {
    if (enable) {
      _logger.d("Setting screen mode to landscape...");
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([]);
    }
  }

  void _registerConfigChangeEvent() {
    _configChangeSub = Pst.eventBus.on<ConfigChangeEvent>().listen((event) {
      if (event is EnableAREvent) {
        _handleEnableAREvent(event);
        return;
      }
      if (event is EnableTVEvent) {
        _handleEnableTVEvent(event);
        return;
      }
    });
  }

  void _connectivitySubscriptionInitialize() async {
    _connectivitySub?.cancel();
    final c = Connectivity();
    final result = await c.checkConnectivity();
    if (!result.contains(ConnectivityResult.none)) {
      await _checkNetworkAvailability();
    }
    _connectivitySub = c.onConnectivityChanged.listen((result) {
      if (_connectivityCheckTimer != null) {
        return;
      }
      _connectivityCheckTimer =
          Timer.periodic(const Duration(seconds: 5), (timer) async {
        bool isConnected = await _checkNetworkAvailability();
        if (isConnected) {
          timer.cancel();
          _connectivityCheckTimer = null;
        }
      });
    });
  }

  void _listenShareMediaFiles() {
    _logger.d("setting up share callbacks.");
    // For sharing images coming from outside the app while the app is in the memory
    _shareMediaFileSub = _shareMediaFileSub ??
        ReceiveSharingIntent.instance.getMediaStream().listen(
            (List<SharedMediaFile> value) {
          _navigateToShareMedia(value);
        }, onError: (err) {
          _logger.d("get intent data stream error: $err");
        });

    // For sharing images coming from outside the app while the app is closed
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      _navigateToShareMedia(value);
    });
  }

  Future<bool> _checkNetworkAvailability() async {
    final res = await api.isUrlReachable(
      "https://www.example.org",
      ignoreNonSocketException: false,
      ignoreStatusCodeError: true,
      logErrors: _isNetworkAvailable,
    );
    setState(() {
      _isNetworkAvailable = res;
    });
    return res;
  }

  void _navigateToShareMedia(List<SharedMediaFile> value) {
    _logger.d("received share media $value");
    if (value.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => ReceiveSharePage(
          files: value,
          showSideBySide: showSideBySide(context),
        ),
      ));
    }
  }

  double get _defaultTextScaleFactor {
    return _enableAR
        ? 0.7
        : _enableTV
            ? 1.2
            : 1.0;
  }

  void _handleEnableAREvent(EnableAREvent onData) {
    if (_enableAR == onData.enable) {
      return;
    }
    _enableAR = onData.enable;
    _setLandscapeMode(_enableAR);
    Global.getThemeEventBus().fire(
      ThemeChangeEvent(textScaleFactor: _defaultTextScaleFactor),
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _handleEnableTVEvent(EnableTVEvent onData) {
    if (_enableTV == onData.enable) {
      return;
    }
    _enableTV = onData.enable;
    if (_enableTV) {
      Global.getThemeEventBus().fire(
        ThemeChangeEvent(themeIndex: ThemeOption.dark.index),
      );
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
    } else {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
    }
    if (mounted) {
      setState(() {});
    }
  }

  Widget get _desktopBody {
    final tr = AppLocalizations.of(context);
    return Wrap(
      spacing: 40,
      runSpacing: 40,
      children: [
        MainButton(
          context,
          Icons.supervisor_account_rounded,
          tr.contactsTitle,
          onPressed: () => _selectPage(
            MainBottomBarPage.contacts.index,
          ),
        ),
        MainButton(
          context,
          Icons.chat_rounded,
          tr.sessionsTitle,
          onPressed: () => _selectPage(
            MainBottomBarPage.sessions.index,
          ),
        ),
        MainButton(
          context,
          Icons.manage_accounts_rounded,
          tr.settingsTitle,
          onPressed: () => _selectPage(
            MainBottomBarPage.settings.index,
          ),
        )
      ],
    );
  }

  Widget _navigationHome({bool showDrawer = true}) {
    final tr = AppLocalizations.of(context);
    return Scaffold(
      appBar: showDrawer ? MainAppBar(title: tr.homeText) : null,
      drawer: showDrawer ? const MainDrawer() : null,
      body: Center(
        child: _desktopBody,
      ),
    );
  }

  Widget get _body {
    return useNavigationRail(context) && !_enableTV
        ? Row(
            children: [
              SafeArea(
                child: MainNavigationRail(
                  onSelected: _selectPage,
                  onNavigateToSelfContactDetails: () async {
                    final c = await getContact(Pst.selfUser?.id);
                    if (c != null && mounted) {
                      setState(() {
                        _rightSide = ContactDetailsPage(
                          contact: c,
                        );
                      });
                    }
                  },
                ),
              ),
              SafeArea(
                child: VerticalDivider(thickness: 1, width: 1),
              ),
              Expanded(
                child: SafeArea(child: _rightSide ?? _pages(showDrawer: false)),
              ),
            ],
          )
        : SafeArea(child: _pages(showDrawer: true));
  }

  double? get _visiblePageIndex {
    return _pageController.hasClients ? _pageController.page : null;
  }

  Widget _page(Widget child, double index) {
    return FocusScope(
      canRequestFocus: _visiblePageIndex == index,
      child: child,
    );
  }

  Widget _pages({bool showDrawer = true}) {
    return Column(
      children: [
        if (_alert != null)
          AlertChip(
            _alert!,
            width: double.infinity,
            onDeleted: () {
              setState(() {
                _alert = null;
              });
            },
          ),
        const NetworkMonitor(),
        Expanded(
          child: PageView(
            key: const Key("home pages"),
            scrollDirection: Axis.horizontal,
            controller: _pageController,
            children: <Widget>[
              _page(_navigationHome(showDrawer: showDrawer), 0),
              _page(AccountAndSettingsPage(), 1),
              _page(Center(child: ContactsPage(showDrawer: showDrawer)), 2),
              _page(Center(child: SessionsPage(showDrawer: showDrawer)), 3),
            ],
          ),
        ),
      ],
    );
  }

  Widget get _homePage {
    final tr = AppLocalizations.of(context);
    return Scaffold(
      key: _scaffoldKey,
      drawer: const MainDrawer(),
      endDrawer: const MainDrawer(),
      body: WillPopWidget(
        popMessage: tr.pressOneMoreTimeToExitTheAppText,
        child: _body,
      ),
      persistentFooterButtons: _isNetworkAvailable
          ? null
          : [SnackbarWidget.e(tr.networkUnavailableHint)],
      bottomNavigationBar: (useNavigationRail(context) || _enableAR)
          ? null
          : const MainBottomBar(),
    );
  }

  void _saveDesktopWindowSize() {
    if (!isDesktop()) {
      return;
    }
    final windowSize = MediaQuery.of(context).size;
    Pst.saveWindowSize(windowSize);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _saveDesktopWindowSize();
    return FutureBuilder<bool>(
      future: _buildStartCompleter.future,
      builder: (context, AsyncSnapshot<bool> snapshot) {
        if (!snapshot.hasData) {
          return Container();
        }
        return StackWith(
          bottom: [_homePage],
          top: loadingWidget(),
          toStackOn: _isLoading,
        );
      },
    );
  }
}
