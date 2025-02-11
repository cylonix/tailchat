// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'friend_info.dart';
import 'friend_request_info.dart';

class Friends {
  List<FriendRequestInfo>? friendRequestList;
  List<FriendInfo>? friendList;
  Friends({
    this.friendRequestList,
    this.friendList,
  });
  factory Friends.fromJson(Map<String, dynamic> json) {
    List<FriendRequestInfo> friendRequestList = <FriendRequestInfo>[];
    List<dynamic> friendRequests = json['FriendRequestList'] ?? [];
    if (friendRequests.isNotEmpty) {
      for (var value in friendRequests) {
        friendRequestList.add(FriendRequestInfo.fromJson(value));
      }
    }
    List<FriendInfo> friendInfoList = <FriendInfo>[];
    List<dynamic> friendInfo = json['Friends'] ?? [];
    if (friendInfo.isNotEmpty) {
      for (var value in friendInfo) {
        friendInfoList.add(FriendInfo.fromJson(value));
      }
    }
    return Friends(
      friendRequestList: friendRequestList,
      friendList: friendInfoList,
    );
  }

}
