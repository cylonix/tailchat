// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

class UnauthenticatedException implements Exception {
  String msg;
  UnauthenticatedException(this.msg);
}
