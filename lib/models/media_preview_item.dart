// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class MediaPreviewItem {
  int? id;
  final String path;
  String? caption;
  File? resource;
  bool isSelected;
  TextEditingController? controller;
  MediaPreviewItem({
    this.id,
    required this.path,
    this.caption,
    this.resource,
    this.controller,
    this.isSelected = false,
  });
}
