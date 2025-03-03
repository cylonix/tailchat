// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:tailchat/gen/l10n/app_localizations.dart';
import 'api/chat_server.dart';
import 'api/config.dart';
import 'api/contacts.dart';
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

class FirstLaunchPage extends StatefulWidget {
  final Function? onFirstLaunchComplete;
  const FirstLaunchPage({super.key, this.onFirstLaunchComplete});

  @override
  State<FirstLaunchPage> createState() => _FirstLaunchPageState();
}

class _FirstLaunchPageState extends State<FirstLaunchPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  StreamSubscription<ChatReceiveNetworkConfigEvent>? _networkConfigEventSub;
  StreamSubscription<SelfUserChangeEvent>? _configSub;
  Alert? _alert;
  Device? _currentDevice;
  bool _createdSelfContact = false;
  String? _systemUsername;
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
          Navigator.of(context).pop();
          toast(context, "Welcome ${Pst.selfUser?.name}!");
        }
        widget.onFirstLaunchComplete?.call();
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
      );
      _logger.d("Current device: $_currentDevice");
    }
    _networkConfigEventSub = ChatServer.getChatEventBus()
        .on<ChatReceiveNetworkConfigEvent>()
        .listen((event) async {
      _logger.d('Received network config: ${event.hostname}');

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
            os: Platform.operatingSystem,
          );
        });
      }
    });
  }

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
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 24,
            children: [
              const SizedBox(height: 24),
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
              if (_currentDevice == null) _alertVpnRunning,
              if (_alert != null) AlertChip(_alert!),
              const SizedBox(height: 24),
              _selfContactForm,
            ],
          ),
        ),
      ),
    );
  }

  Widget get _alertVpnRunning {
    return Container(
      padding: EdgeInsets.all(16),
      color: const Color.fromARGB(255, 19, 17, 19),
      child: Text(
        'Waiting for Tailscale to start. If it\'s already enabled '
        'and running, please check your network connection.',
        style: TextStyle(
          color: Colors.orangeAccent,
          fontSize: 18,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  bool _modifyUsername = false;
  Widget get _usernameInput {
    if (_modifyUsername || (_systemUsername ?? "").isEmpty) {
      return BaseTextInput(
        controller: _usernameController,
        label: 'Your username*',
        hint: 'Enter a username to identify yourself to other users.',
        maxLines: null,
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
      );
    }
    return ListTile(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Username: $_systemUsername"),
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
      subtitle: Text(
        "Username is to identify yourself to other Tailchat users. "
        "Username of '$_systemUsername' is based on your running environment. "
        "Please edit it if you prefer a different username.",
      ),
    );
  }

  Widget get _selfContactForm {
    final device = _currentDevice;
    final address =
        device?.address != device?.hostname ? "${device?.address} " : "";
    return Container(
      alignment: Alignment.center,
      constraints: const BoxConstraints(maxWidth: 600),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 8,
          children: [
            _usernameInput,
            if (device != null)
              ListTile(
                leading: getOsIcon(Platform.operatingSystem),
                title: Text('Device: ${device.hostname}'),
                subtitle: Text('${address}Port: ${device.port}'),
              ),
            const SizedBox(height: 24),
            BaseInputButton(
              onPressed: _saveProfile,
              width: double.infinity,
              height: 48,
              filledButton: true,
              child: const Text('Continue'),
            ),
            const UserAgreement(),
            const SizedBox(height: 48),
            const Image(
              image: AssetImage("lib/assets/images/tailchat.png"),
              width: 128,
              height: 128,
            ),
          ],
        ),
      ),
    );
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Waiting for device configuration... Is Tailscale running?',
          ),
        ),
      );
      return;
    }

    final username = _usernameController.text;
    final error = validateUsername(context, username);
    if (error != null) {
      setState(() {
        _alert = Alert(error);
      });
    }
    _currentDevice!.userID = Contact.generateID(username);
    final contact = Contact(
      username: _usernameController.text,
      devices: [_currentDevice!],
    );
    try {
      _createdSelfContact = true;
      await addContact(contact);
    } catch (e) {
      _logger.e("Failed to add contact");
      if (mounted) {
        setState(() {
          _alert = Alert("Failed to add contact: $e");
        });
      }
      return;
    }
    await Pst.saveSelfUser(contact);
    await Pst.saveSelfDevice(_currentDevice);

    _logger.d("Profile saved. First launch complete.");
    if (mounted) {
      Navigator.of(context).pop();
      toast(context, "Profile saved. First launch complete.");
    }
    widget.onFirstLaunchComplete?.call();
  }
}
