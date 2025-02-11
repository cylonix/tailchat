// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

abstract class UIEvent {
  UIEvent();
}

class HomePageLoadingEvent extends UIEvent {
  final bool isLoading;
  final void Function()? onTimeout;
  HomePageLoadingEvent({
    required this.isLoading,
    this.onTimeout,
  }) : super();
}
