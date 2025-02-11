// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

class Note extends StatefulWidget {
  final TextEditingController textController;
  final String? hintText;
  const Note({
    super.key,
    required this.textController,
    this.hintText,
  });

  @override
  State<Note> createState() => _NoteState();
}

class _NoteState extends State<Note> {
  @override
  Widget build(BuildContext context) {
    final decoration = InputDecoration(
      hintText: widget.hintText,
      filled: true,
      fillColor: Theme.of(context).dividerColor,
      border: InputBorder.none,
    );
    return ListTile(
      title: TextField(
        controller: widget.textController,
        decoration: decoration,
      ),
    );
  }
}
