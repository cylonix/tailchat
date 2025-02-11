// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'base_input/text_input.dart';

class SearchWidget extends StatelessWidget {
  final void Function()? onSearchCleared;
  final void Function(String)? onSearchChanged;
  final void Function(String)? onSearchSubmitted;
  final String? Function(String?)? validator;
  final bool autofocus;
  final String? hintText;
  final Widget? editIcon;
  final GlobalKey<FormFieldState>? formKey;
  final FocusNode? nextFocus;
  const SearchWidget({
    super.key,
    this.onSearchChanged,
    this.autofocus = false,
    this.editIcon,
    this.formKey,
    this.hintText,
    this.nextFocus,
    this.onSearchCleared,
    this.onSearchSubmitted,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return BaseTextInput(
      editIcon: editIcon,
      formKey: formKey,
      hint: hintText,
      icon: editIcon != null ? null : Icons.search,
      autoFocus: autofocus,
      border: InputBorder.none,
      inputAction: nextFocus != null ? null : TextInputAction.go,
      nextFocus: nextFocus,
      validator: validator,
      onChanged: onSearchChanged,
      onSubmitted: onSearchSubmitted,
    );
  }
}
