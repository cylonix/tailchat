// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';

class ChatSendPeersResult {
  final bool success;
  final int successUserCnt;
  final int successCnt;
  final int failureCnt;
  final Map<String, bool>? statusMap;
  final String? successMsg;
  final String? failureMsg;
  ChatSendPeersResult({
    required this.success,
    this.successCnt = 0,
    this.failureCnt = 0,
    this.successUserCnt = 0,
    this.statusMap,
    this.successMsg,
    this.failureMsg,
  });
  factory ChatSendPeersResult.fromJson(Map<String, dynamic> json) {
    return ChatSendPeersResult(
      success: json['success'],
      successCnt: json['successCnt'],
      failureCnt: json['failureCnt'],
      successUserCnt: json['successUserCnt'],
      statusMap: Map.castFrom(json['statusMap'] ?? {}),
      successMsg: json['successMsg'],
      failureMsg: json['failureMsg'],
    );
  }

  Map<String, dynamic> _toJson({bool statsOnly = false}) {
    var m = {
      'success': success,
      'successCnt': successCnt,
      'failureCnt': failureCnt,
      'successUserCnt': successUserCnt,
      'statusMap': statsOnly ? null : statusMap,
      'successMsg': statsOnly ? null : successMsg,
      'failureMsg': statsOnly ? null : failureMsg,
    };
    m.removeWhere((key, value) => value == null);
    return m;
  }

  Map<String, dynamic> toJson() {
    return _toJson();
  }

  @override
  String toString() {
    return jsonEncode(this);
  }

  String toStatsOnlyString() {
    return jsonEncode(_toJson(statsOnly: true));
  }
}
