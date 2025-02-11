// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

/// Paging controller facilitate the index handling of paging a list of items.
class PagingController {
  final int length;
  final int pageSize;

  PagingController({required this.length, required this.pageSize}) {
    _maxPageIndex = length ~/ pageSize;
    _lastPageItemsCount = length % pageSize;
    enableDown = length > pageSize;
  }

  int _maxPageIndex = 0;
  int _lastPageItemsCount = 0;
  int _pageIndex = 0;
  bool enableUp = false;
  bool enableDown = false;

  int get currentPageStart {
    return _pageIndex * pageSize;
  }

  int get currentPageEnd {
    return _pageIndex >= _maxPageIndex
        ? _pageIndex * pageSize + _lastPageItemsCount
        : (_pageIndex + 1) * pageSize;
  }

  int get currentPageItemCount {
    return _maxPageIndex == 0
        ? _lastPageItemsCount
        : (_pageIndex >= _maxPageIndex)
            ? _lastPageItemsCount
            : pageSize;
  }

  int itemIndex(int indexInPage) {
    return indexInPage + pageSize * _pageIndex;
  }

  /// Returns true if page moved up.
  bool pageUp() {
    if (!enableUp) {
      return false;
    }
    _pageIndex--;
    enableUp = _pageIndex > 0;
    enableDown = true;
    return true;
  }

  /// Returns true if page moved down.
  bool pageDown() {
    if (!enableDown) {
      return false;
    }
    _pageIndex++;
    enableUp = true;
    enableDown = _pageIndex < _maxPageIndex;
    return true;
  }
}
