// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../api/config.dart';
import '../models/session.dart';
import 'paged_list.dart';
import 'session_widget.dart';

class SessionList extends StatefulWidget {
  const SessionList({
    super.key,
    required this.itemSelectedCallback,
    this.itemDeleteCallback,
    required this.sessions,
    this.filterText,
    this.selectedItem,
    this.showEditButton = true,
    this.showPopUpMenuOnLongPressed = true,
    this.showPopupMenuOnTap = false,
    this.itemsPerPage = 6,
    this.itemsPerRow = 2,
    this.enableScroll = true,
    this.minItemWidth,
  });

  final void Function(int, Session) itemSelectedCallback;
  final void Function(int, Session)? itemDeleteCallback;
  final List<Session> sessions;
  final Session? selectedItem;
  final String? filterText;
  final bool showEditButton;
  final bool showPopUpMenuOnLongPressed;
  final bool showPopupMenuOnTap;
  final bool enableScroll;
  final int itemsPerPage;
  final int itemsPerRow;
  final int? minItemWidth;

  @override
  State<SessionList> createState() => _SessionListState();
}

class _SessionListState extends State<SessionList> {
  Session? _selected;
  late List<Session> _sessions;

  @override
  void initState() {
    super.initState();
    _setSessions();
  }

  @override
  Widget build(BuildContext context) {
    _setSessions();
    return widget.enableScroll ? _listView : _pagedListView;
  }

  void _setSessions() {
    _sessions = (widget.filterText != null)
        ? widget.sessions.where((s) => s.contains(widget.filterText!)).toList()
        : widget.sessions;
    if (widget.selectedItem != null) {
      _selected = widget.selectedItem;
    }
  }

  Widget get _pagedListView {
    return PagedList(
      minItemWidth: widget.minItemWidth,
      itemBuilder: (({
        required index,
        required itemHeight,
        required itemWidth,
      }) {
        final s = _sessions[index];
        return SizedBox(
          height: itemHeight,
          width: itemWidth,
          child: SessionWidget(
            margin: EdgeInsets.zero,
            showAvatar: true,
            showEditButton: false,
            session: s,
            padding: const EdgeInsets.all(0),
            shape: _shape,
            onTap: () => widget.itemSelectedCallback(index, s),
            onDelete: () => widget.itemDeleteCallback?.call(index, s),
          ),
        );
      }),
      itemsCount: _sessions.length,
    );
  }

  Widget get _listView {
    if (Pst.enableTV ?? false) {
      return _listViewForTV;
    }
    if (_sessions.isEmpty) {
      return Container(
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(left: 16, right: 16, top: 64),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            "Please create a chat by tapping the '+' button.",
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      controller: ScrollController(),
      shrinkWrap: true,
      itemBuilder: (context, index) => _listViewItem(index),
      itemCount: _sessions.length,
    );
  }

  Widget _listViewItem(int index) {
    final item = _sessions[index];
    return SessionWidget(
      key: Key(item.sessionID),
      color: item.equal(_selected)
          ? Theme.of(context).highlightColor.withValues(alpha: 0.3)
          : null,
      session: item,
      onTap: () {
        setState(() {
          _selected = item;
        });
        widget.itemSelectedCallback(index, item);
      },
      showAvatar: true,
      showEditButton: widget.showEditButton,
      showPopupMenuOnTap: widget.showPopupMenuOnTap,
      showPopupMenuOnLongPressed: widget.showPopUpMenuOnLongPressed,
      onDelete: () => widget.itemDeleteCallback?.call(index, item),
    );
  }

  Widget get _listViewForTV {
    return Column(
      children: [
        const SizedBox(height: 300),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final count = (maxWidth / 400).floor();
            return GridView.builder(
              padding: const EdgeInsets.all(8),
              controller: ScrollController(),
              itemCount: _sessions.length,
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                crossAxisCount: count,
                childAspectRatio: 2,
              ),
              itemBuilder: (context, index) => _listViewItem(index),
            );
          },
        ),
      ],
    );
  }

  ShapeBorder get _shape {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8.0),
    );
  }
}
