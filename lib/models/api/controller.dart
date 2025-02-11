// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
part 'controller.g.dart';

@JsonSerializable(includeIfNull: false, fieldRename: FieldRename.snake)
class Controller {
  const Controller({
    this.locale = "en",
    required this.name,
    required this.description,
    required this.baseUrl,
    required this.uiBaseUrl,
    required this.vpnBaseUrl,
    required this.officialWebsite,
    this.contactEmail,
    this.meetServerRootDomain,
    this.iosAppLink,
    this.androidAppLink,
    this.androidAppAutoUpdateJsonUrl,
    this.thirdPartyLoginsSupported,
    this.phoneNumberCountries,
  });

  /// Name of the controller.
  /// e.g. "main-aws-ca-usa"
  final String name;

  /// Description of the controller.
  /// A bit more detailed description of the controller.
  /// e.g. "Main controller in AWS in CA, USA."
  final String description;

  /// Preferred locale.
  final String locale;

  /// Controller base url.
  final String baseUrl;

  /// Controller ui base url.
  final String uiBaseUrl;

  /// Controller mesh vpn api url.
  final String vpnBaseUrl;

  /// Office website so that further information can be looked up.
  final String officialWebsite;

  /// Support contact email.
  final String? contactEmail;

  /// 3rd party logins supported.
  final List<String>? thirdPartyLoginsSupported;

  /// Phone number countries supported.
  final List<String>? phoneNumberCountries;

  /// Meeting server root domain.
  final String? meetServerRootDomain;

  /// IOS app link.
  final String? iosAppLink;

  /// Android app link.
  final String? androidAppLink;

  /// Android app auto update json file location.
  final String? androidAppAutoUpdateJsonUrl;

  /// Use the generated json serializations.
  factory Controller.fromJson(Map<String, dynamic> json) =>
      _$ControllerFromJson(json);
  Map<String, dynamic> toJson() => _$ControllerToJson(this);

  @override
  String toString() {
    return jsonEncode(this);
  }
}
