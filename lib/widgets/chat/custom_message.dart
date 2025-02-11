// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

/// A class that represents custom message widget.
class CustomMessage extends StatefulWidget {
  /// Creates an emoji message widget based on [types.CustomMessage]
  const CustomMessage({
    super.key,
    required this.message,
    required this.messageWidth,
  });

  /// [types.CustomMessage]
  final types.CustomMessage message;

  /// Maximum message width
  final int messageWidth;

  @override
  State<CustomMessage> createState() => _CustomMessageState();
}

/// [CustomMessage] widget state
class _CustomMessageState extends State<CustomMessage> {
  @override
  Widget build(BuildContext context) {
    // todo: support custom message.
    return SizedBox();
  }
}
