// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import '../contacts/device.dart';
import '../contacts/user_profile.dart';

abstract class ConfigChangeEvent {
  ConfigChangeEvent();
}

class ConfigLoadedEvent extends ConfigChangeEvent {
  ConfigLoadedEvent() : super();
}

class EnableAREvent extends ConfigChangeEvent {
  final bool enable;

  EnableAREvent({
    required this.enable,
  }) : super();
}

class EnableTVEvent extends ConfigChangeEvent {
  final bool enable;

  EnableTVEvent({
    required this.enable,
  }) : super();
}

class SelfUserChangeEvent extends ConfigChangeEvent {
  final UserProfile? newSelfUser;
  SelfUserChangeEvent({
    this.newSelfUser,
  }) : super();
}

class SelfDeviceChangeEvent extends ConfigChangeEvent {
  final Device? newDevice;
  SelfDeviceChangeEvent({
    this.newDevice,
  }) : super();
}
