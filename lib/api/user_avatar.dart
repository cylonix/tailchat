// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

//import 'dart:convert';
//import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
//import 'api.dart' as api;
//import '../model/api/user_avatar_change_event.dart';
//import '../model/image_resize.dart';
import '../models/api/status.dart';
import '../utils/utils.dart';

Future<Uint8List?> getUserAvatar(
  String? userID, {
  bool forceUpdate = false,
}) async {
  try {
    // Use an in memory cache before file based image store is ready.
    Uint8List? avatar;
    //bool cacheExpired = true;
    if (userID != null && !forceUpdate) {
      /*final user = Cylonixd.getUser(userInt64ID);
      if (user != null) {
        final now = DateTime.now();
        final lastUpdated = user.avatarLastUpdated;
        if (lastUpdated != null && now.difference(lastUpdated).inDays < 1) {
          //cacheExpired = false;
          return user.avatarImage;
        }
      }*/
    }
    /*if (cacheExpired) {
      final loginName = Cylonixd.getUser(userInt64ID)?.loginName;
      final result = await api.getUserAvatar(loginName);
      if (result != null) {
        avatar = const Base64Decoder().convert(result);
        if (userInt64ID != null) {
          Cylonixd.saveUserAvatar(userInt64ID, avatar);
        }
      }
    }*/
    return avatar;
  } catch (e) {
    //Global.logger.e("failed to get user avatar: $e");
  }
  return null;
}

Future<Status?> changeUserAvatar(String userID) async {
  //Uint8List? avatarData;
  try {
    if (isMobile()) {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxHeight: 120,
      );
      if (image != null) {
        //avatarData = await image.readAsBytes();
      }
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result != null) {
        //avatarData = await resizeImage(File(result.files.first.path as String));
      }
    }
  } catch (e) {
    return Status(false, '$e');
  }

  /*
  if (avatarData != null && avatarData.isNotEmpty) {
    final status = await api.updateUserAvatar(base64Encode(avatarData));
    if (status.success) {
      Cylonixd.saveUserAvatar(userID, avatarData);
      api.apiEventBus.fire(UserAvatarChangeEvent(
        userID: userID,
        avatar: avatarData,
      ));
    }
    return status;
  }*/
  // User canceled
  return null;
}
