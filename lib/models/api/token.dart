// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

class Token {
  String token;
  String vpnAuthKey;

  Token({
    required this.token,
    required this.vpnAuthKey,
  });

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      token: json['token'],
      vpnAuthKey: json['vpn_auth_key'],
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'vpn_auth_key': vpnAuthKey,
      };

  String get shortString {
    var t = token;
    if (t.length > 25) {
      t = t.substring(0, 25);
    }
    var v = vpnAuthKey;
    if (v.length > 15) {
      v = v.substring(0, 25);
    }
    return "[$t/$v]";
  }

  @override
  String toString() {
    return toJson().toString();
  }
}
