// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

class ListPicker extends StatefulWidget {
  const ListPicker({
    super.key,
    required this.count,
    this.initialIndex,
    required this.itemBuilder,
    this.onSelected,
  });
  final int count;
  final int? initialIndex;
  final void Function(int?)? onSelected;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  State<ListPicker> createState() => _ListPickerState();
}

class _ListPickerState extends State<ListPicker> {
  int? _selected;

  ScrollController? _controller;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialIndex;
    _controller = FixedExtentScrollController(initialItem: _selected ?? 10);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (int index = 0; index < widget.count; index++) {
      items.add(TextButton(
        onFocusChange: (value) {
          if (value) {
            _selectItem(index);
          }
        },
        child: widget.itemBuilder(context, index),
        onPressed: () => _selectItem(index),
      ));
    }
    return ListWheelScrollView(
      useMagnifier: true,
      physics: const FixedExtentScrollPhysics(),
      controller: _controller,
      itemExtent: 40,
      children: items,
    );
  }

  void _selectItem(int index) {
    setState(() {
      _selected = index;
    });
    widget.onSelected?.call(index);
  }
}
