// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'token.dart';

class TokenChangeEvent extends TokenEvent {
  final Token token;
  TokenChangeEvent({required this.token}) : super();
}

class TokenRemoveEvent extends TokenEvent {
  TokenRemoveEvent() : super();
}

class TokenInvalidEvent extends TokenEvent {
  TokenInvalidEvent() : super();
}

class TokenEvent {
  TokenEvent();
}
