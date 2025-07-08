// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'api/chat_server.dart';
import 'api/config.dart';
import 'api/contacts.dart';
import 'gen/l10n/app_localizations.dart';
import 'models/alert.dart';
import 'models/chat/chat_event.dart';
import 'models/contacts/device.dart';
import 'models/contacts/contact.dart';
import 'models/config/config_change_event.dart';
import 'utils/logger.dart';
import 'utils/utils.dart';
import 'widgets/alert_chip.dart';
import 'widgets/base_input/text_input.dart';
import 'widgets/base_input/button.dart';
import 'widgets/base_input/user_agreement.dart';
import 'widgets/common_widgets.dart';
import 'widgets/contacts/device_dialog.dart';
import 'widgets/shake_widget.dart';

final _logger = Logger(tag: "FirstLaunch");

class FirstLaunchPage extends StatelessWidget {
  final Function? onFirstLaunchComplete;
  const FirstLaunchPage({super.key, this.onFirstLaunchComplete});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Welcome to Tailchat'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 24,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Text(
                  tr.introWords,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Let\'s set up your profile',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              isApple()
                  ? CupertinoButton.filled(
                      borderRadius: BorderRadius.circular(8),
                      sizeStyle: CupertinoButtonSize.medium,
                      onPressed: () => _showInputForm(context),
                      child: const Text("Get Started"),
                    )
                  : BaseInputButton(
                      onPressed: () => _showInputForm(context),
                      width: double.infinity,
                      filledButton: true,
                      child: const Text("Get Started"),
                    ),
              const UserAgreement(),
              Text(
                tr.disclaimer,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              const Image(
                image: AssetImage("lib/assets/images/tailchat.png"),
                width: 128,
                height: 128,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInputForm(BuildContext context) async {
    final height = MediaQuery.of(context).size.height;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      constraints: BoxConstraints(
        minWidth: double.infinity,
        maxHeight: height * 0.9,
      ),
      isScrollControlled: true,
      builder: (c) => const _SetupView(),
    );
    if (ok == true) {
      _logger.d("First launch profile setup completed.");
      if (context.mounted) {
        Navigator.of(context).pop(true);
      }
      onFirstLaunchComplete?.call();
    } else {
      _logger.d("First launch profile setup cancelled.");
    }
  }
}

class _SetupView extends StatefulWidget {
  const _SetupView();

  @override
  State<_SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<_SetupView> {
  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _usernameController = TextEditingController();
  StreamSubscription<ChatReceiveNetworkConfigEvent>? _networkConfigEventSub;
  StreamSubscription<SelfUserChangeEvent>? _configSub;
  Alert? _alert;
  Device? _currentDevice;
  bool _createdSelfContact = false;
  String? _systemUsername;
  String? _alertSetter;
  final _logger = Logger(tag: "FirstLaunch");

  @override
  void initState() {
    _logger.d('initState');
    super.initState();
    _getCurrentUser();
    _setupConfigListener();
    _setupNetworkConfigListener();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _configSub?.cancel();
    _networkConfigEventSub?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentUser() async {
    try {
      String? username;
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isWindows) {
        username = Platform.environment['USERNAME'];
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        username = iosInfo.utsname.nodename.split('s-')[0];
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _logger.d("Android info: $androidInfo");
      } else {
        // macOS, Linux
        username =
            Platform.environment['USER'] ?? Platform.environment['LOGNAME'];
      }
      _logger.d('System username: $username');

      _systemUsername = username?.toLowerCase();
      if (_systemUsername != null && _systemUsername != 'localhost') {
        _usernameController.text = _systemUsername!;
        if (mounted) {
          setState(() {
            // Update UI.
          });
        }
      }
    } catch (e) {
      _logger.e('Failed to get system username: $e');
    }
  }

  void _setupConfigListener() {
    _configSub = Pst.eventBus.on<SelfUserChangeEvent>().listen((event) {
      if (Pst.selfUser != null && !_createdSelfContact) {
        if (mounted) {
          Navigator.of(context).pop(true);
          toast(context, "Welcome ${Pst.selfUser?.name}!");
        }
      }
    });
  }

  void _setupNetworkConfigListener() {
    if (ChatServer.hostname != null && ChatServer.address != null) {
      _currentDevice = Device(
        userID: "", // To be set once profile is setup.
        address: ChatServer.address!,
        hostname: ChatServer.hostname!,
        port: ChatServer.port ?? 50311,
        os: Platform.operatingSystem,
        isPhysical: ChatServer.isPhysicalAddress,
      );
      _logger.d("Current device: $_currentDevice");
    }
    _networkConfigEventSub = ChatServer.getChatEventBus()
        .on<ChatReceiveNetworkConfigEvent>()
        .listen((event) async {
      _logger.d('Received network config: $event');

      if (event.hostname == null || event.address == null) {
        if (mounted) {
          setState(() {
            _currentDevice = null;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _currentDevice = Device(
            userID: "", // To be set once profile is setup.
            address: event.address!,
            hostname: event.hostname!,
            port: event.port ?? 50311,
            isPhysical: event.isPhysical,
            os: Platform.operatingSystem,
          );
          if (!event.isPhysical) {
            if (_alertSetter == "localNetworkAccess") {
              _alert = null; // Clear alert if related to local network access.
            }
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 16),
        ListTile(
          leading: IconButton(
            icon: Icon(
              isApple() ? CupertinoIcons.chevron_back : Icons.arrow_back,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Setup your profile',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
            ),
          ),
          trailing: isApple()
              ? CupertinoButton.tinted(
                  sizeStyle: CupertinoButtonSize.medium,
                  borderRadius: BorderRadius.circular(8),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                )
              : FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_currentDevice == null ||
                      (_currentDevice?.isPhysical ?? false))
                    _alertVpnRunning,
                  if (_alert != null) AlertChip(_alert!),
                  const SizedBox(height: 24),
                  _selfContactForm,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget get _alertVpnRunning {
    return ShakeWidget(
      key: _shakeKey,
      shakeCount: 5,
      shakeOffset: 30,
      child: Column(
        children: [
          Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: [
            Icon(
              isApple()
                  ? CupertinoIcons.exclamationmark_circle
                  : Icons.warning_amber_outlined,
              color: Colors.orange.shade700,
            ),
            Text(
              'Waiting for Tailscale or Cylonix to start...',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ]),
          Text(
            'If it\'s already enabled and running, please check its '
            'status. Or you can proceed with the current physical address '
            'or manual setup to chat over other type of mesh networks.',
            style: TextStyle(
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  bool _modifyUsername = false;
  Widget get _usernameInput {
    if (_modifyUsername ||
        (_systemUsername ?? "").isEmpty ||
        _systemUsername == 'localhost') {
      return Column(
        spacing: 4,
        children: [
          const Text('Enter a username to identify yourself to other users:'),
          BaseTextInput(
            controller: _usernameController,
            label: 'Your username*',
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter your username';
              }
              return null;
            },
            onChanged: (v) {
              setState(() {
                // Update UI
              });
            },
          ),
        ],
      );
    }
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Username: $_systemUsername",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _modifyUsername = true;
                });
              },
            ),
          ],
        ),
        Text(
          "Username is to identify yourself to other Tailchat users. "
          "'$_systemUsername' is based on your running environment. "
          "Please edit it if you prefer a different username.",
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String get _continueLabel {
    final device = _currentDevice;
    if (device == null || device.isPhysical) {
      return 'Continue with manual setup';
    }
    return 'Continue';
  }

  Widget get _selfContactForm {
    final device = _currentDevice;
    final subtitles = device?.subtitles ?? [];
    return Container(
      alignment: Alignment.center,
      constraints: const BoxConstraints(maxWidth: 360),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 8,
          children: [
            _usernameInput,
            if (device != null)
              Row(
                spacing: 8,
                mainAxisSize: MainAxisSize.min,
                children: [
                  getOsIcon(Platform.operatingSystem),
                  Column(
                    children: [
                      Text(
                        'Your device: ${device.title} '
                        '${device.isPhysical ? "(Physical)" : ""}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitles.isNotEmpty) Text(subtitles[0]),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 24),
            if (device != null && device.isPhysical) ...[
              isApple()
                  ? SizedBox(
                      width: 320,
                      child: CupertinoButton.filled(
                        borderRadius: BorderRadius.circular(8),
                        sizeStyle: CupertinoButtonSize.medium,
                        onPressed: _saveProfile,
                        child: const Text("Continue with physical address"),
                      ),
                    )
                  : BaseInputButton(
                      onPressed: _saveProfile,
                      width: 320,
                      filledButton: true,
                      child: const Text("Continue with physical address"),
                    ),
              const SizedBox(height: 8),
              isApple()
                  ? SizedBox(
                      width: 320,
                      child: CupertinoButton.tinted(
                        borderRadius: BorderRadius.circular(8),
                        sizeStyle: CupertinoButtonSize.medium,
                        onPressed: _saveProfile,
                        child: Text(_continueLabel),
                      ),
                    )
                  : BaseInputButton(
                      onPressed: _saveProfile,
                      width: 320,
                      filledButton: true,
                      child: Text(_continueLabel),
                    ),
            ],
            if (device == null || !device.isPhysical)
              isApple()
                  ? SizedBox(
                      width: 320,
                      child: CupertinoButton.filled(
                        borderRadius: BorderRadius.circular(8),
                        sizeStyle: CupertinoButtonSize.medium,
                        onPressed: _saveProfile,
                        child: Text(_continueLabel),
                      ),
                    )
                  : BaseInputButton(
                      onPressed: _saveProfile,
                      width: 320,
                      filledButton: true,
                      child: Text(_continueLabel),
                    ),
          ],
        ),
      ),
    );
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final username = _usernameController.text;
    final error = validateUsername(context, username);
    if (error != null) {
      setState(() {
        _alert = Alert(error);
        _alertSetter = "usernameValidation";
      });
    }
    final contactID = Contact.generateID(username);
    if (_currentDevice == null) {
      toast(
        context,
        'Unknown device tailnet hostname... Is Tailscale or Cylonix running? '
        'Proceeding with manual setup.',
        color: const Color.fromARGB(255, 119, 72, 1),
      );
      _shakeKey.currentState?.shake();
      _currentDevice = await showDialog(
        context: context,
        builder: (context) => DeviceDialog(
          contact: contactID,
          isTailnet: false,
        ),
      );
      if (_currentDevice == null) {
        _logger.e("Must setup this device first.");
        if (mounted) {
          setState(() {
            _alert = Alert("No device is setup yet.");
            _alertSetter = "noDeviceSetup";
          });
        }
        return;
      }
    }

    _currentDevice!.userID = contactID;
    final contact = Contact(
      username: _usernameController.text,
      devices: [_currentDevice!],
    );
    try {
      _createdSelfContact = true;
      await addContact(contact, mergeIfExists: true);
    } catch (e) {
      _logger.e("Failed to add contact");
      if (mounted) {
        setState(() {
          _alert = Alert("Failed to add contact: $e");
          _alertSetter = "addContact";
        });
      }
      return;
    }
    await Pst.saveSelfUser(contact);
    await Pst.saveSelfDevice(_currentDevice);

    _logger.d("Profile saved. First launch complete.");
    if (mounted) {
      Navigator.of(context).pop(true);
      toast(context, "Profile saved. First launch complete.");
    }
  }
}
