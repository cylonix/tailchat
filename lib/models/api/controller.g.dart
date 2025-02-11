// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'controller.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Controller _$ControllerFromJson(Map<String, dynamic> json) => Controller(
      locale: json['locale'] as String? ?? "en",
      name: json['name'] as String,
      description: json['description'] as String,
      baseUrl: json['base_url'] as String,
      uiBaseUrl: json['ui_base_url'] as String,
      vpnBaseUrl: json['vpn_base_url'] as String,
      officialWebsite: json['official_website'] as String,
      contactEmail: json['contact_email'] as String?,
      meetServerRootDomain: json['meet_server_root_domain'] as String?,
      iosAppLink: json['ios_app_link'] as String?,
      androidAppLink: json['android_app_link'] as String?,
      androidAppAutoUpdateJsonUrl:
          json['android_app_auto_update_json_url'] as String?,
      thirdPartyLoginsSupported:
          (json['third_party_logins_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      phoneNumberCountries: (json['phone_number_countries'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$ControllerToJson(Controller instance) {
  final val = <String, dynamic>{
    'name': instance.name,
    'description': instance.description,
    'locale': instance.locale,
    'base_url': instance.baseUrl,
    'ui_base_url': instance.uiBaseUrl,
    'vpn_base_url': instance.vpnBaseUrl,
    'official_website': instance.officialWebsite,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('contact_email', instance.contactEmail);
  writeNotNull(
      'third_party_logins_supported', instance.thirdPartyLoginsSupported);
  writeNotNull('phone_number_countries', instance.phoneNumberCountries);
  writeNotNull('meet_server_root_domain', instance.meetServerRootDomain);
  writeNotNull('ios_app_link', instance.iosAppLink);
  writeNotNull('android_app_link', instance.androidAppLink);
  writeNotNull(
      'android_app_auto_update_json_url', instance.androidAppAutoUpdateJsonUrl);
  return val;
}
