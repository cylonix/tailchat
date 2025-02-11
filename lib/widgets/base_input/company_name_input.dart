// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'text_input.dart';

class CompanyNameInput extends StatelessWidget {
  final FocusNode? focus;
  final FocusNode? nextFocus;
  final String? initialValue;
  final void Function(String)? onChanged;
  const CompanyNameInput({
    super.key,
    this.focus,
    this.nextFocus,
    this.initialValue,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BaseTextInput(
      text: initialValue,
      hint: "Company name",
      label: "Company name",
      icon: Icons.home,
      focus: focus,
      nextFocus: nextFocus,
      validator: (v) => _validate(context, v),
      onChanged: onChanged,
    );
  }

  String? _validate(BuildContext context, String? v) {
    return null;
  }
}
