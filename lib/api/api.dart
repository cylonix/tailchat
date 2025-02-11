// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:event_bus/event_bus.dart';
import 'package:http/http.dart' as http;

import '../models/api/status.dart';
import '../utils/global.dart';

final apiEventBus = EventBus();

Status parseResponse(String caller, http.Response resp) {
  final code = resp.statusCode;
  switch (code) {
    case 400:
      final decoded = json.decode(resp.body);
      final detail = decoded['error_code'];
      Global.logger.d("$caller failed ($code): $detail");
      return Status.withErrorCode(decoded['error_code']);
    case 401:
      return Status.local(false, LocalMsgKey.unauthenticated);
    case 201:
    case 200:
      Global.logger.d('$caller success.');
      return Status.ok;
    default:
      return Status(false, "$caller failed: code=$code ${resp.body}");
  }
}

/// Check if a url a reachable through http get.
Future<bool> isUrlReachable(
  String serverUrl, {
  int retry = 0,
  bool ignoreStatusCodeError = false,
  bool ignoreNonSocketException = false,
  bool logErrors = true,
}) async {
  for (var i = 0; i <= retry; i++) {
    if (await isUrlReachableOnce(
      serverUrl,
      ignoreStatusCodeError: ignoreStatusCodeError,
      ignoreNonSocketException: ignoreNonSocketException,
      logErrors: logErrors,
    )) {
      return true;
    }
  }
  return false;
}

Future<bool> isUrlReachableOnce(
  String serverUrl, {
  bool ignoreStatusCodeError = false,
  bool ignoreNonSocketException = false,
  bool logErrors = true,
}) async {
  final url = Uri.parse(serverUrl);
  try {
    final resp = await http.get(url).timeout(const Duration(seconds: 5));
    if (resp.statusCode != 200 && !ignoreStatusCodeError) {
      if (logErrors) {
        Global.logger.e("resp body: ${resp.body}");
      }
      throw Exception(resp.body);
    }
    return true;
  } on SocketException catch (e) {
    if (logErrors) {
      Global.logger.e("socket exception: $e");
    }
    return false;
  } catch (e) {
    if (logErrors) {
      Global.logger.e("server not reachable: $e");
    }
    if (ignoreNonSocketException) {
      return true;
    }
  }

  return false;
}

String? encodeQueryParameters(Map<String, String> params) {
  return params.entries
      .map((e) =>
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
}
