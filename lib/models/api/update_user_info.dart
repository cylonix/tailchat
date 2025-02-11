// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
part 'update_user_info.g.dart';

@JsonSerializable(includeIfNull: false, fieldRename: FieldRename.snake)
class UpdateUserInfo {
  final String? email;
  final bool? emailUpdated;
  final String? firstName;
  final bool? firstNameUpdated;
  final String? lastName;
  final bool? lastNameUpdated;
  final String mobile;
  final bool? mobileUpdated;
  final String? password;
  final bool? passwordUpdated;
  final String? username;
  final bool? usernameUpdated;
  final String verifyCode;
  UpdateUserInfo({
    required this.mobile,
    required this.verifyCode,
    this.email,
    this.emailUpdated,
    this.firstName,
    this.firstNameUpdated,
    this.lastName,
    this.lastNameUpdated,
    this.username,
    this.usernameUpdated,
    this.mobileUpdated,
    this.password,
    this.passwordUpdated,
  });

  UpdateUserInfo copyWith({String? password}) {
    return UpdateUserInfo(
      mobile: mobile,
      verifyCode: verifyCode,
      email: email,
      emailUpdated: emailUpdated,
      firstName: firstName,
      firstNameUpdated: firstNameUpdated,
      lastName: lastName,
      lastNameUpdated: lastNameUpdated,
      username: username,
      usernameUpdated: usernameUpdated,
      mobileUpdated: mobileUpdated,
      password: password ?? this.password,
    );
  }

  /// Use the generated json serializations.
  factory UpdateUserInfo.fromJson(Map<String, dynamic> json) =>
      _$UpdateUserInfoFromJson(json);
  Map<String, dynamic> toJson() => _$UpdateUserInfoToJson(this);

  @override
  String toString() {
    return jsonEncode(this);
  }

  /// Safestring masks the password field.
  String toSafeString() {
    if (password != null) {
      return copyWith(password: '******').toString();
    }
    return toString();
  }

  bool get isNotEmpty {
    return usernameUpdated == true ||
        firstNameUpdated == true ||
        emailUpdated == true ||
        lastNameUpdated == true ||
        mobileUpdated == true;
  }

  bool get isEmpty {
    return !isNotEmpty;
  }
}
