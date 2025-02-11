// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../../api/config.dart';
import '../../models/contacts/contacts_repository.dart';
import '../../models/contacts/device.dart';
import '../../widgets/common_widgets.dart';
import '../stack_icons.dart';

class UserStatus extends StatefulWidget {
  final String userID;
  final List<Device>? peers;

  const UserStatus({
    super.key,
    required this.userID,
    this.peers,
  });

  @override
  State<UserStatus> createState() => _UserStatusState();
}

class _UserStatusState extends State<UserStatus> {
  List<Device>? _devices;
  ContactsRepository? _repository;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  @override
  void didUpdateWidget(UserStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userID != widget.userID || oldWidget.peers != widget.peers) {
      _loadDevices();
    }
  }

  Future<void> _loadDevices() async {
    if (widget.peers != null) {
      setState(() => _devices = widget.peers);
    } else {
      try {
        _repository ??= await ContactsRepository.getInstance();
        final devices = (await _repository?.getContact(widget.userID))?.devices;
        if (mounted) {
          setState(() => _devices = devices);
        }
      } catch (e) {
        debugPrint('Error loading devices: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = _devices;
    final onlineDevices = devices?.where((p) => p.isOnline).toList();
    final chatDevices = devices?.where((p) => p.isAvailable).toList();
    var greenDeviceCount = onlineDevices?.length ?? 0;
    var chatDeviceCount = chatDevices?.length ?? 0;
    var deviceCount = devices?.length ?? 0;

    if (widget.userID == Pst.selfUser?.id) {
      deviceCount += 1;
      final selfDevice = Pst.selfDevice;
      if (selfDevice?.isAvailable ?? false) {
        chatDeviceCount += 1;
      }
      if (selfDevice?.isOnline ?? false) {
        greenDeviceCount += 1;
      }
    }

    final offlineDeviceCount = deviceCount - greenDeviceCount;
    greenDeviceCount -= chatDeviceCount;
    final hasOnlineDevice = greenDeviceCount > 0;
    final hasOfflineDevice = offlineDeviceCount > 0;
    final hasChatDevice = chatDeviceCount > 0;
    final chatIcon = StackIcons(
      Icons.chat,
      Icons.online_prediction,
      color1: Colors.green,
      color2: Colors.green,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasChatDevice) chatIcon,
        if (hasChatDevice) Text("$chatDeviceCount"),
        if (hasChatDevice) const SizedBox(width: 8),
        if (hasOnlineDevice) const OnlineStatusIcon(true),
        if (hasOnlineDevice) Text("$greenDeviceCount"),
        if (hasOnlineDevice) const SizedBox(width: 8),
        if (hasOfflineDevice) const OnlineStatusIcon(false),
        if (hasOfflineDevice) Text("$offlineDeviceCount"),
      ],
    );
  }
}
