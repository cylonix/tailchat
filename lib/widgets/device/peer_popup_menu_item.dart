// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'package:sprintf/sprintf.dart';
import '../../models/contacts/device.dart';
import '../common_widgets.dart';

class PeerPopupMenuItem extends PopupMenuItem<Device> {
  // ignore: use_super_parameters
  PeerPopupMenuItem({
    Key? key,
    required Device peer,
    bool online = true,
  }) : super(
          key: key,
          value: peer,
          child: ListTile(
            title: Text(sprintf("%-16s %s", [peer.address, peer.hostname])),
            leading: getOsOnlineIcon(peer.os, online),
          ),
        );
}
