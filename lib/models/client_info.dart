// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';

class ClientInfo {
  String os;
  String machine;
  String? ip;
  String? hostname;
  String? osVersion;

  ClientInfo({
    required this.os,
    required this.machine,
    this.ip,
    this.hostname,
    this.osVersion,
  });
  factory ClientInfo.fromJson(Map<String, dynamic> json) {
    return ClientInfo(
      os: json['os'],
      machine: json['machine'],
      ip: json['ip'],
      hostname: json['hostname'],
      osVersion: json['osVersion'],
    );
  }

  Map<String, dynamic> toJson() {
    var m = {
      'os': os,
      'machine': machine,
      'ip': ip,
      'hostname': hostname,
      'osVersion': osVersion,
    };
    m.removeWhere((key, value) => value == null);
    return m;
  }

  @override
  String toString() {
    return json.encode(this);
  }
}
