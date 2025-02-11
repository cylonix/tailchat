// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'session.dart';

abstract class SessionEvent {
  final Session? session;
  const SessionEvent({this.session});
}

class SessionUpdateEvent extends SessionEvent {
  const SessionUpdateEvent(Session session) : super(session: session);
}

class SessionsSavedEvent extends SessionEvent {
  SessionsSavedEvent() : super();
}
