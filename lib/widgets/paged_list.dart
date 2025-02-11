// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../gen/l10n/app_localizations.dart';
import '../models/paging_controller.dart';
import '../utils/logger.dart';

class PagedList extends StatefulWidget {
  const PagedList({
    super.key,
    required this.itemBuilder,
    required this.itemsCount,
    this.itemsPerPage = 6,
    this.itemsPerRow = 2,
    this.maxItemHeight = 200,
    this.minItemWidth,
  });

  final Widget Function({
    required int index,
    required double itemHeight,
    required double itemWidth,
  }) itemBuilder;
  final int itemsPerPage;
  final int itemsPerRow;
  final int itemsCount;
  final double maxItemHeight;
  final int? minItemWidth;

  @override
  State<PagedList> createState() => _PagedListState();
}

class _PagedListState extends State<PagedList> {
  late PagingController _pagingController;
  int selectedIndex = -1;
  late int _itemsPerPage, _itemsPerRow;
  final _logger = Logger(tag: "Paged-list");

  @override
  void initState() {
    super.initState();
    _itemsPerPage = widget.itemsPerPage;
    _itemsPerRow = widget.itemsPerRow;
    _setupPaging();
  }

  void _setupPaging() {
    _pagingController = PagingController(
      length: widget.itemsCount,
      pageSize: _itemsPerPage,
    );
  }

  @override
  void didUpdateWidget(covariant PagedList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if the current page sessions and controller needs to be reset.
    if (oldWidget.itemsCount != widget.itemsCount) {
      _logger.i("Paged list updated with different length");
      _itemsPerPage = widget.itemsPerPage;
      _itemsPerRow = widget.itemsPerRow;
      _setupPaging();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _pagedListView;
  }

  void _pageUp() {
    if (!_pagingController.pageUp()) {
      return;
    }
    setState(() {});
  }

  void _pageDown() {
    if (!_pagingController.pageDown()) {
      return;
    }
    setState(() {});
  }

  bool get _showPageUp {
    return _pagingController.enableUp;
  }

  bool get _showPageDown {
    return _pagingController.enableDown;
  }

  Widget get _pagedListView {
    final tr = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final rows = (_itemsPerPage / _itemsPerRow).floor();
          var itemHeight = (h - 8) / rows - 4;
          var itemWidth = (w - 8) / _itemsPerRow - 4;
          final minItemWidth = widget.minItemWidth;
          if (minItemWidth != null && itemWidth <= minItemWidth) {
            itemWidth = w - 8;
            _itemsPerPage = rows;
            _itemsPerRow = 1;
            _setupPaging();
          }
          if (itemHeight > widget.maxItemHeight) {
            itemHeight = widget.maxItemHeight;
          }
          var boxHeight = (itemHeight + 4) * rows + 8;
          if (boxHeight > h) {
            boxHeight = h;
          }
          return Row(
            children: [
              Flexible(
                child: SizedBox(
                  height: boxHeight,
                  child: GridView.builder(
                    itemCount: _pagingController.currentPageItemCount,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      crossAxisCount: _itemsPerRow,
                      childAspectRatio: (itemWidth / itemHeight),
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      return widget.itemBuilder(
                        index: _pagingController.itemIndex(index),
                        itemHeight: itemHeight,
                        itemWidth: itemWidth,
                      );
                    },
                  ),
                ),
              ),
              if (_showPageUp || _showPageDown)
                SizedBox(
                  width: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (_showPageUp)
                        Column(children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_upward),
                            tooltip: tr.pageUpText,
                            onPressed: _pageUp,
                          ),
                          Text(tr.pageUpText, textAlign: TextAlign.center),
                        ]),
                      if (_showPageDown)
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_downward),
                              tooltip: tr.pageDownText,
                              onPressed: _pageDown,
                            ),
                            Text(tr.pageDownText, textAlign: TextAlign.center),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
