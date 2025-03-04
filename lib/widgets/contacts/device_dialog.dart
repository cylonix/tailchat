// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tailchat/api/dns.dart';
import '../alert_chip.dart';
import '../common_widgets.dart';
import '../../api/chat_server.dart';
import '../../api/contacts.dart';
import '../../models/alert.dart';
import '../../models/chat/chat_event.dart';
import '../../models/contacts/device.dart';
import '../../utils/utils.dart';

class DeviceDialog extends StatefulWidget {
  final Device? device;
  final String contact;
  final List<String>? exclude;

  const DeviceDialog(
      {super.key, this.device, this.exclude, required this.contact});

  @override
  State<DeviceDialog> createState() => _DeviceDialogState();
}

class _DeviceDialogState extends State<DeviceDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _hostnameController;
  late TextEditingController _portController;
  StreamSubscription<ChatReceiveNetworkConfigEvent>? _networkConfigSub;
  List<Device> _devicesKnown = [];
  String? _selectedDevice;
  Alert? _alert;
  bool _editPort = false;

  @override
  void initState() {
    super.initState();
    _devicesKnown = ChatServer.deviceList
        .whereNot((d) => widget.exclude?.contains(d.hostname) ?? false)
        .toList();
    _hostnameController = TextEditingController(text: widget.device?.hostname);
    _portController = TextEditingController(
      text: widget.device?.port.toString() ?? '50311',
    );
    _networkConfigSub = ChatServer.getChatEventBus()
        .on<ChatReceiveNetworkConfigEvent>()
        .listen((_) {
      if (mounted) {
        setState(() {
          _devicesKnown = ChatServer.deviceList;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actionsPadding: const EdgeInsets.only(right: 48, top: 16, bottom: 32),
      title: Text(widget.device == null ? 'Add Device' : 'Edit Device'),
      content: Form(
        key: _formKey,
        child: Container(
          padding: EdgeInsets.only(left: 16),
          constraints: BoxConstraints(
            minWidth: isMediumScreen(context) ? 500 : 350,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              const SizedBox(height: 16),
              if (_alert != null) AlertChip(_alert!),
              if (_devicesKnown.isNotEmpty) ...[
                const Text(
                  "Please select a device from the known devices "
                  "or input its tailnet hostname or IP address:",
                ),
                _devicesDropDownMenu,
              ],
              if (_devicesKnown.isEmpty) ...[
                const Text(
                  "Copy and paste the device's tailnet hostname or IP address:",
                ),
                TextFormField(
                  controller: _hostnameController,
                  decoration: InputDecoration(
                    labelText: 'Hostname/IP',
                    hintText: 'Enter hostname or IP address',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter hostname or IP';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 16,
                    children: [
                      Text(
                        "Advanced options:",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Icon(
                        _editPort
                            ? CupertinoIcons.chevron_up
                            : CupertinoIcons.chevron_down,
                        size: 20,
                      ),
                    ],
                  ),
                  onTap: () => setState(() {
                    _editPort = !_editPort;
                  }),
                ),
              ),
              if (_editPort) ...[
                const Text(
                  "Enter port number. Normally just leave it as default:",
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _portController,
                  decoration: InputDecoration(
                    constraints: const BoxConstraints(maxWidth: 300),
                    labelText: 'Port',
                    hintText: 'Enter port number if is not the default',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter port';
                    }
                    final port = int.tryParse(value);
                    if (port == null || port < 1 || port > 65535) {
                      return 'Port must be between 1 and 65535';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: _saveDevice,
          child: Text('Save'),
        ),
      ],
    );
  }

  Widget get _devicesDropDownMenu {
    return DropdownMenu<String>(
      controller: _hostnameController,
      enableFilter: true,
      requestFocusOnTap: true,
      leadingIcon: const Icon(Icons.devices),
      label: const Text('Hostname/IP address'),
      inputDecorationTheme: InputDecorationTheme(
        constraints: BoxConstraints(
          minWidth: isMediumScreen(context) ? 480 : 320,
        ),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 5.0),
      ),
      onSelected: (value) {
        setState(() {
          _selectedDevice = value;
          _hostnameController.text = value ?? "";
        });
      },
      dropdownMenuEntries: _devicesKnown
          .map<DropdownMenuEntry<String>>(
            (d) => DropdownMenuEntry<String>(
              value: d.hostname,
              label: d.hostname,
              leadingIcon: getOsIcon(d.os),
              trailingIcon: _selectedDevice == d.hostname
                  ? Icon(Icons.check, size: 18)
                  : null,
            ),
          )
          .toList(),
    );
  }

  void _saveDevice() async {
    if (!_formKey.currentState!.validate()) return;
    var hostname = _hostnameController.text;
    var device = await getDevice(Device.generateID(hostname));
    if (device != null) {
      final contact = await getContact(device.userID);
      if (mounted) {
        setState(() {
          _alert = Alert(
            'Device $hostname already exists for ${contact?.name} '
            'Please select or enter a different hostname.',
          );
        });
      }
      return;
    }
    String? address;
    if (InternetAddress.tryParse(hostname) != null) {
      address = hostname;
      hostname = await resolveHostname(address);
    } else {
      address = _devicesKnown
              .firstWhereOrNull((d) => d.hostname == hostname)
              ?.address ??
          await resolveV4Address(hostname);
    }
    if (address == null) {
      if (mounted) {
        setState(() {
          _alert = Alert("Invalid hostname. Cannot find its address.");
        });
      }
      return;
    }

    device = Device(
      userID: widget.contact,
      address: address,
      hostname: hostname,
      port: int.parse(_portController.text),
    );
    if (mounted) {
      Navigator.pop(context, device);
    }
  }

  @override
  void dispose() {
    _hostnameController.dispose();
    _portController.dispose();
    _networkConfigSub?.cancel();
    super.dispose();
  }
}
