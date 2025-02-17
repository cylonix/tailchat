// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../models/alert.dart';

class AlertChip extends Card {
  AlertChip(
    Alert alert, {
    super.key,
    Function()? onDeleted,
    Color? backgroundColor,
    double? fontSize,
    double? width,
  }) : super(
          margin: EdgeInsets.all(0),
          color: backgroundColor ?? alert.background,
          child: ListTile(
            leading: alert.avatar,
            title: width == null
                ? Text(
                    alert.text,
                    style: TextStyle(color: alert.color, fontSize: fontSize),
                  )
                : SizedBox(
                    width: width,
                    child: Text(
                      alert.text,
                      style: TextStyle(color: alert.color, fontSize: fontSize),
                    ),
                  ),
            trailing: onDeleted != null
                ? IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: onDeleted,
                  )
                : null,
          ),
        );
}
