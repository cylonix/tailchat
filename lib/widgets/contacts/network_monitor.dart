// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../api/chat_server.dart';
import '../../api/config.dart';
import '../../api/contacts.dart';
import '../../models/alert.dart';
import '../../models/chat/chat_event.dart';
import '../../models/contacts/contact.dart';
import '../../models/contacts/device.dart';
import '../../utils/logger.dart';
import '../../utils/utils.dart';
import '../../widgets/alert_chip.dart';
import '../../widgets/dialog_action.dart';
import '../../widgets/contacts/hostname_change_dialog.dart';

class NetworkMonitor extends StatefulWidget {
  final bool showDrawer;
  const NetworkMonitor({super.key, this.showDrawer = true});

  @override
  State<NetworkMonitor> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<NetworkMonitor> {
  static final _logger = Logger(tag: 'NetworkMonitor');
  StreamSubscription<ChatReceiveNetworkEvent>? _networkEventSub;
  Alert? _alert;
  static final hostnameChangeDialogRouteName = "HostnameChangeDialog";

  @override
  Widget build(BuildContext context) {
    return (_alert != null)
        ? AlertChip(
            _alert!,
            width: double.infinity,
            onDeleted: () {
              setState(() {
                _alert = null;
              });
            },
          )
        : Container();
  }

  Future<void> _handleStartingWithNewContact(String hostname, String address,
      {int? port}) async {
    final selfDevice = await getDevice(Device.generateID(hostname));
    if (selfDevice == null) {
      _logger.d("Hostname is ready. User should be at the first launch page.");
      return;
    }
    final selfContact = await getContact(selfDevice.userID);
    if (selfContact == null) {
      _logger.e("Found device but not contact. Not expected. $hostname");
      return;
    }
    _logger.d("Self contact found: ${selfContact.name}");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome ${selfContact.name}!'),
        ),
      );
    }
    await Pst.saveSelfUser(selfContact);
    await Pst.saveSelfDevice(selfDevice);
    return;
  }

  void _removeCurrentHostnameChangeDialog() {
    var showingHostnameChangeDialog = false;
    Navigator.maybeOf(context)?.popUntil((route) {
      _logger.d("route setting=${route.settings}");
      final currentName = route.settings.name;
      if (currentName == hostnameChangeDialogRouteName) {
        showingHostnameChangeDialog = true;
      }
      _logger.d("current name is $currentName");
      // Stop popping
      return true;
    });
    if (showingHostnameChangeDialog) {
      _logger.d("HostnameChangeDialog is showing. Pop it.");
      Navigator.of(context).pop();
    }
  }

  void _showUpdateSelfDeviceDialog(
    String currentDevice,
    String currentAddress,
    String address,
    String hostname,
  ) async {
    setState(() {
      _alert = null;
    });

    final update = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      routeSettings: RouteSettings(name: hostnameChangeDialogRouteName),
      builder: (context) {
        return AlertDialog.adaptive(
          title: Text("Hostname changed"),
          content: Text(
            "Hostname changed from $currentDevice to $hostname "
            "for $currentAddress",
          ),
          actions: [
            DialogAction(
              isDestructive: true,
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Ignore"),
            ),
            DialogAction(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text("Update"),
            ),
          ],
        );
      },
    );
    if (update ?? false) {
      final selfDevice = Pst.selfDevice!;
      final newDevice = Device(
        userID: selfDevice.userID,
        address: address,
        hostname: hostname,
        port: selfDevice.port,
      );
      try {
        await addDevice(newDevice);
        await deleteDevice(selfDevice.id);
        await Pst.saveSelfDevice(newDevice);
      } catch (e) {
        _logger.e("Failed to update device $hostname");
        if (mounted) {
          setState(() {
            _alert = Alert(
              "Failed to update device hostname to "
              "$hostname: $e",
              setter: "network_config_update_device_$hostname",
            );
          });
        }
      }
    }
  }

  void _showAddNewDeviceDialog(Contact selfContact, Device newDevice) async {
    final contact = await showDialog<Contact>(
      context: context,
      barrierDismissible: false,
      routeSettings: RouteSettings(name: hostnameChangeDialogRouteName),
      builder: (context) => HostnameChangeDialog(
        currentContact: selfContact,
        currentDevice: Pst.selfDevice!,
        newDevice: newDevice,
      ),
    );
    if (contact == null) {
      _logger.e("Not adding self contact is not expected");
      return;
    }
    try {
      newDevice.userID = contact.id;
      Pst.saveSelfDevice(newDevice);
      Pst.saveSelfUser(contact);
    } catch (e) {
      _logger.e("Failed to save contact ${contact.username}: $e");
      if (mounted) {
        setState(() {
          _alert = Alert("Failed to save contact ${contact.username}: $e");
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _alert = null;
        });
      }
    }
  }

  void _handleNetworkAvailable(bool available) async {
    if (available) {
      if (mounted && _alert?.setter == "network_available_event") {
        setState(() {
          _alert = null;
        });
        toast(context, "Network is now available", color: Colors.green);
      }
      return;
    }
    if (mounted && _alert == null) {
      setState(() {
        _alert = Alert(
          "Network is not available",
          setter: "network_available_event",
        );
      });
      toast(context, "Network is not available", color: Colors.red);
    }
  }

  void _handleNetworkConfig(ChatReceiveNetworkConfigEvent event) async {
    final currentDevice = Pst.selfDevice?.hostname ?? "";
    final currentAddress = Pst.selfDevice?.address ?? "";
    final selfContactID = Pst.selfUser?.id ?? "";
    final address = event.address ?? "";
    final hostname = event.hostname ?? "";
    final Contact? selfContact;
    _logger.d("Network config event $event received");
    if (selfContactID.isEmpty) {
      _logger.d('Self contact not found');
      if (hostname.isEmpty) {
        _logger.d("Hostname is not yet known. Skipping.");
        if (_alert == null) {
          if (mounted) {
            setState(() {
              _alert = Alert(
                "Cannot detect tailnet hostname and address. "
                "Is mesh network like Tailscale or Cylonix running?",
                setter: "network_config_empty_hostname",
              );
            });
          }
        }
        return;
      }
      if (_alert != null) {
        if (mounted) {
          setState(() {
            _alert = null;
          });
        }
      }
      try {
        await _handleStartingWithNewContact(
          hostname,
          address,
          port: event.port,
        );
      } catch (e) {
        _logger.e("failed to start with new contact: $e");
      }
      return;
    }

    // Current user exists. Check if the hostname matches.
    try {
      selfContact = await getContact(selfContactID);
    } catch (e) {
      _logger.e("Failed to get self contact: $e");
      return;
    }
    if (selfContact == null) {
      _logger.e('Self contact not found');
      if (mounted) {
        setState(() {
          _alert = Alert(
            'Self contact not found. Please add a contact.',
          );
        });
      }
      return;
    }
    final selfContact2 = selfContact;

    _logger.d('New hostname "$hostname"');
    if (hostname.isEmpty) {
      if (mounted) {
        setState(() {
          _alert = Alert(
            "Is mesh network like Tailscale or Cylonix down?",
            setter: "network_config_empty_hostname",
          );
        });
      }
      return;
    }
    if (_alert?.setter == "network_config_empty_hostname") {
      if (mounted) {
        toast(context, 'Hostname detected: "$hostname"');
        setState(() {
          _alert = null;
        });
      }
    }

    if (currentDevice == hostname) {
      _logger.d('No change in device name. Ignore.');
      return;
    }

    if (mounted &&
        _alert?.setter != "network_config_hostname_change_$hostname") {
      toast(context, 'New hostname detected: "$hostname"');
    }

    // Hostname changed. Check if the device is ours.
    final selfDevice =
        selfContact.devices.firstWhereOrNull((d) => d.hostname == hostname);
    if (selfDevice != null) {
      _logger.d('Self device changed to $hostname.');
      await Pst.saveSelfDevice(selfDevice);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device changed to $hostname'),
          ),
        );
      }
      return;
    }
    var device = await getDevice(Device.generateID(hostname));
    var contact = await getContact(device?.userID);

    // Check if we just got a new name for the same IP.
    // We assume IP assigned is static and hence allow for name change.
    if (currentAddress == address) {
      if (contact != null && contact.id != selfContactID) {
        if (mounted) {
          setState(() {
            _alert = Alert(
              'Address conflict: ${contact.username} '
              'has $hostname with the same $address.',
              setter: "network_config_address_conflict",
            );
          });
        }
        _removeCurrentHostnameChangeDialog();
        return;
      }
      _logger.d("Hostname changed for the same address.");
      if (mounted) {
        if (_alert?.setter == "network_config_hostname_change_$hostname") {
          return;
        }
        _removeCurrentHostnameChangeDialog();
        setState(() {
          _alert = Alert(
            "Hostname changed from $currentDevice to $hostname",
            setter: "network_config_hostname_change_$hostname",
            actions: [
              AlertAction(
                "Ignore",
                onPressed: () => setState(
                  () {
                    _alert = null;
                  },
                ),
                icon: isApple() ? CupertinoIcons.xmark : Icons.close,
                destructive: true,
              ),
              AlertAction(
                "Update",
                onPressed: () => _showUpdateSelfDeviceDialog(
                  currentDevice,
                  currentAddress,
                  address,
                  hostname,
                ),
                icon: isApple()
                    ? CupertinoIcons.arrow_up_right_square
                    : Icons.sync_rounded,
              ),
            ],
          );
        });
      }
      return;
    }

    // Self device changed and its not currently ours. Confirm with user if the
    // user also changed.
    if (contact == null) {
      _logger.d('New address. hostname is not known to be ours');
      final newDevice = Device(
        userID: "",
        address: address,
        hostname: hostname,
        port: event.port ?? 50311,
      );
      if (mounted) {
        _logger.d("Change alert to add new device");
        if (_alert?.setter == "network_config_hostname_change_$hostname") {
          return;
        }
        _removeCurrentHostnameChangeDialog();
        setState(() {
          _alert = Alert(
            "Hostname changed from $currentDevice to $hostname and "
            "address changed from $currentAddress to $address.",
            setter: "network_config_hostname_change_$hostname",
            actions: [
              AlertAction(
                "Ignore",
                onPressed: () => setState(() {
                  _alert = null;
                }),
                icon: isApple() ? CupertinoIcons.xmark : Icons.close,
                destructive: true,
              ),
              AlertAction(
                "Update to the new device",
                onPressed: () => _showAddNewDeviceDialog(
                  selfContact2,
                  newDevice,
                ),
                icon: isApple() ? CupertinoIcons.add : Icons.add,
              ),
            ],
          );
        });
      }
      return;
    }

    if (contact.id == selfContactID) {
      _logger.d('switch device to known device: $hostname.');
      await Pst.saveSelfDevice(device);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device changed to $hostname'),
          ),
        );
      }
      _removeCurrentHostnameChangeDialog();
      return;
    }
    _removeCurrentHostnameChangeDialog();
    _logger.d('Switch to a new user: ${contact.name}@$hostname.');
    await Pst.saveSelfDevice(device);
    await Pst.saveSelfUser(contact);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switch to a new user ${contact.name}@$hostname.'),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _subscribeToNetworkConfigEvents();
  }

  @override
  void dispose() {
    _networkEventSub?.cancel();
    super.dispose();
  }

  void _subscribeToNetworkConfigEvents() {
    _logger.d("Subscribing to the network events");
    final currentHostname = ChatServer.hostname;
    final currentAddress = ChatServer.address;
    if (currentHostname != null && currentAddress != null) {
      Future.microtask(
        () => _handleNetworkConfig(
          ChatReceiveNetworkConfigEvent(
            hostname: currentHostname,
            address: currentAddress,
            port: ChatServer.port,
            subscriberPort: ChatServer.subscriberPort,
          ),
        ),
      );
    }
    if (!ChatServer.isNetworkAvailable) {
      _alert ??= Alert(
        "Network is not available",
        setter: "network_available_event",
      );
    }
    _networkEventSub = ChatServer.getChatEventBus()
        .on<ChatReceiveNetworkEvent>()
        .listen((event) {
      if (event is ChatReceiveNetworkConfigEvent) {
        _handleNetworkConfig(event);
        return;
      }
      if (event is ChatReceiveNetworkAvailableEvent) {
        _handleNetworkAvailable(event.available);
      }
    });
  }
}
