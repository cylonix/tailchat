// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../gen/l10n/app_localizations.dart';

/// For today's show Hms, otherwise, show yMd.
class TimeText extends StatelessWidget {
  final TextAlign? textAlign;
  final TextStyle? style;
  final double? textScaleFactor;
  final DateTime time;
  const TimeText({
    super.key,
    required this.time,
    this.style,
    this.textAlign,
    this.textScaleFactor,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      _getTimeString(context, time),
      style: style,
      textAlign: textAlign,
    );
  }

  String _getTimeString(BuildContext context, DateTime t) {
    if (t.year < 2000) {
      return "";
    }
    final tr = AppLocalizations.of(context);
    String locale = Localizations.localeOf(context).languageCode;
    final now = DateTime.now();
    if (t.day == now.day && t.month == now.month && t.year == now.year) {
      return "${tr.todayLabel} ${DateFormat.Hm(locale).format(t)}";
    }
    return "${DateFormat.yMd(locale).format(t)} ${DateFormat.Hm(locale).format(t)}";
  }
}
