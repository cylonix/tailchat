// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_user_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateUserInfo _$UpdateUserInfoFromJson(Map<String, dynamic> json) =>
    UpdateUserInfo(
      mobile: json['mobile'] as String,
      verifyCode: json['verify_code'] as String,
      email: json['email'] as String?,
      emailUpdated: json['email_updated'] as bool?,
      firstName: json['first_name'] as String?,
      firstNameUpdated: json['first_name_updated'] as bool?,
      lastName: json['last_name'] as String?,
      lastNameUpdated: json['last_name_updated'] as bool?,
      username: json['username'] as String?,
      usernameUpdated: json['username_updated'] as bool?,
      mobileUpdated: json['mobile_updated'] as bool?,
      password: json['password'] as String?,
      passwordUpdated: json['password_updated'] as bool?,
    );

Map<String, dynamic> _$UpdateUserInfoToJson(UpdateUserInfo instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('email', instance.email);
  writeNotNull('email_updated', instance.emailUpdated);
  writeNotNull('first_name', instance.firstName);
  writeNotNull('first_name_updated', instance.firstNameUpdated);
  writeNotNull('last_name', instance.lastName);
  writeNotNull('last_name_updated', instance.lastNameUpdated);
  val['mobile'] = instance.mobile;
  writeNotNull('mobile_updated', instance.mobileUpdated);
  writeNotNull('password', instance.password);
  writeNotNull('password_updated', instance.passwordUpdated);
  writeNotNull('username', instance.username);
  writeNotNull('username_updated', instance.usernameUpdated);
  val['verify_code'] = instance.verifyCode;
  return val;
}
