// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../base_input/text_input.dart';
import '../../utils/logger.dart';

class UserProfileInput extends StatefulWidget {
  final String? initialUsername;
  final String? initialName;
  final String? initialProfileUrl;
  final void Function(String username, String name, String profileUrl)?
      onChanged;
  final GlobalKey<FormState>? formKey;
  final bool usernameReadOnly;
  final bool usernameMustChange;

  const UserProfileInput({
    super.key,
    this.initialUsername,
    this.initialName,
    this.initialProfileUrl,
    this.onChanged,
    this.formKey,
    this.usernameReadOnly = false,
    this.usernameMustChange = false,
  });

  @override
  State<UserProfileInput> createState() => _UserProfileInputState();
}

class _UserProfileInputState extends State<UserProfileInput> {
  static final _logger = Logger(tag: "UserProfileInput");
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _profileUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _logger.d("Initial username: ${widget.initialUsername}");
    _usernameController.text = widget.initialUsername ?? '';
    _nameController.text = widget.initialName ?? '';
    _profileUrlController.text = widget.initialProfileUrl ?? '';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _profileUrlController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onChanged?.call(
      _usernameController.text,
      _nameController.text,
      _profileUrlController.text,
    );
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Username is required';
    }
    if (value.length < 5) {
      return 'Username should be 5 letters or longer';
    }
    if (value == widget.initialUsername) {
      return "Please input a different username to ${widget.initialUsername}";
    }
    return null;
  }

  String? _validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return null; // URL is optional
    }
    try {
      final uri = Uri.parse(value);
      if (!uri.isAbsolute) {
        return 'Please enter a valid URL';
      }
    } catch (e) {
      return 'Please enter a valid URL';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        spacing: 16,
        children: [
          BaseTextInput(
            controller: _usernameController,
            label: widget.usernameReadOnly ? "Username" : 'Username*',
            hint: "Username is to identify you to other chat users.",
            maxLines: null,
            validator: _validateUsername,
            readOnly: widget.usernameReadOnly,
            onChanged: (v) => _notifyChange(),
          ),
          BaseTextInput(
            controller: _nameController,
            label: 'Display Name',
            hint: "Optional display name",
            onChanged: (v) => _notifyChange(),
          ),
          BaseTextInput(
            controller: _profileUrlController,
            label: 'Profile URL',
            hint: "Optional profile picture url",
            maxLines: null,
            validator: _validateUrl,
            onChanged: (v) => _notifyChange(),
          ),
        ],
      ),
    );
  }
}
