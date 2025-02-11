// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:json_annotation/json_annotation.dart';

/// The generic qr code token state.
@JsonEnum()
enum TokenState {
  created,
  scanned,
  expired,
  confirmed,
}
