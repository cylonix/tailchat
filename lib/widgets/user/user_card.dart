// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../../models/contacts/user_profile.dart';
import '../../models/contacts/contacts_repository.dart';
import '../../utils/utils.dart';
import '../gradient_card.dart';
import 'user_avatar.dart';

class UserCard extends StatefulWidget {
  final Color? backgroundColor;
  final FocusNode? focus;
  final Widget? leading;
  final Widget? child;
  final Widget? avatarChild;
  final Widget? trailing;
  final ShapeBorder? shape;
  final EdgeInsetsGeometry? contentPadding;
  final MainAxisAlignment mainAxisAlignment;
  final UserProfile? user;
  final String? userID;
  final bool noMargin;
  final bool noGradient;
  final void Function()? onTap;
  final bool autoFocus;

  const UserCard({
    super.key,
    this.user,
    this.userID,
    this.backgroundColor,
    this.focus,
    this.leading,
    this.child,
    this.avatarChild,
    this.trailing,
    this.shape,
    this.contentPadding,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.noMargin = false,
    this.noGradient = false,
    this.onTap,
    this.autoFocus = false,
  });

  @override
  State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
  UserProfile? _userProfile;
  ContactsRepository? _contactsRepository;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void didUpdateWidget(UserCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userID != widget.userID || oldWidget.user != widget.user) {
      _loadUserProfile();
    }
  }

  Future<void> _loadUserProfile() async {
    if (widget.user != null) {
      setState(() => _userProfile = widget.user);
    } else if (widget.userID != null) {
      try {
        _contactsRepository ??= await ContactsRepository.getInstance();
        final profile = await _contactsRepository?.getContact(widget.userID!);
        if (mounted) {
          setState(() => _userProfile = profile);
        }
      } catch (e) {
        debugPrint('Error loading user profile: $e');
      }
    }
  }

  Widget _getUserAvatar({UserProfile? user, Widget? child}) {
    const double size = 32;
    String? username;
    String? userID;
    Color? color;
    if (child == null) {
      if (user == null) {
        child = const Icon(Icons.account_circle_rounded, size: size);
      } else {
        userID = user.id;
        username = user.name;
      }
    }
    return UserAvatar(
      key: Key(username ?? "self"),
      size: size,
      color: color,
      userID: userID,
      username: username,
      enableUpdate: false,
      child: child,
    );
  }

  EdgeInsetsGeometry get _margin {
    return widget.noMargin
        ? const EdgeInsets.all(0)
        : const EdgeInsets.only(top: 4);
  }

  Widget get _avatar {
    return Padding(
      padding: widget.contentPadding ??
          const EdgeInsets.only(
            left: 4,
            right: 4,
          ),
      child: widget.avatarChild ?? _getUserAvatar(user: _userProfile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inkWellW = Material(
      type: MaterialType.transparency,
      child: InkWell(
        autofocus: widget.autoFocus,
        focusNode: widget.focus,
        onTap: widget.onTap,
        child: Row(
          mainAxisAlignment: widget.mainAxisAlignment,
          children: [
            if (widget.leading != null) widget.leading!,
            if (widget.child == null) Expanded(child: _avatar),
            if (widget.child != null) _avatar,
            if (widget.child != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 4,
                    right: 4,
                    top: 8,
                    bottom: 8,
                  ),
                  child: widget.child,
                ),
              ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
      ),
    );
    if (widget.noGradient) {
      return Card.outlined(
        color: widget.backgroundColor,
        margin: _margin,
        shape: widget.shape,
        child: Padding(padding: const EdgeInsets.all(8), child: inkWellW),
      );
    }
    return GradientCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xff12c2e9),
          if (isDarkMode(context)) Colors.purple,
          const Color.fromARGB(255, 95, 236, 201),
        ],
      ),
      shadowColor: const Color(0xff12c2e9).withValues(alpha: 0.25),
      elevation: 4,
      shape: widget.shape,
      margin: _margin,
      child: Padding(padding: const EdgeInsets.all(8), child: inkWellW),
    );
  }
}
