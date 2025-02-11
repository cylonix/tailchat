// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';

class QrOneTimeToken {
  String? status;
  String? userAgent;
  String? token;
  QrOneTimeToken({
    required this.token,
    this.userAgent,
    this.status,
  });

  factory QrOneTimeToken.fromJson(Map<String, dynamic> json) {
    return QrOneTimeToken(
      userAgent: json['user_agent'],
      token: json['token'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "status": status,
      'user_agent': userAgent,
      'token': token,
    };
  }

  @override
  String toString() {
    return json.encode(this);
  }
}
