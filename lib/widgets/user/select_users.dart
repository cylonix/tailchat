// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

import '../../api/config.dart';
import '../../api/contacts.dart';
import '../../gen/l10n/app_localizations.dart';
import '../../models/contacts/contact.dart';
import '../../models/contacts/device.dart';
import '../../models/contacts/user_profile.dart';
import '../base_input/button.dart';
import '../common_widgets.dart';
import '../paged_list.dart';
import '../device/peer_popup_menu_item.dart';
import '../snackbar_widget.dart';
import 'user_card.dart';

/// Provide a list of users to select from. Parent widget must be expandable.
class SelectUsers extends StatefulWidget {
  final void Function(
    List<UserProfile>, {
    Device? device,
  }) onSelected;
  final String? title;
  final String? selectButtonText;
  final List<String>? exclude;
  final bool chooseOnlyOneUser;
  final bool chooseOnlyOneDevice;
  final bool Function(Device)? deviceFilter;
  final bool Function(UserProfile)? userFilter;
  final List<UserProfile>? inputUsers;
  final int itemsPerPage;
  final int itemsPerRow;
  final bool enableScroll;
  const SelectUsers({
    super.key,
    this.title,
    this.exclude,
    this.deviceFilter,
    this.selectButtonText,
    this.inputUsers,
    this.chooseOnlyOneUser = false,
    this.chooseOnlyOneDevice = false,
    this.userFilter,
    required this.onSelected,
    this.itemsPerPage = 6,
    this.itemsPerRow = 2,
    this.enableScroll = true,
  });
  @override
  State<SelectUsers> createState() => _SelectUsersState();
}

class _SelectUsersState extends State<SelectUsers> {
  final _selectedIndexMap = <int, bool?>{};
  final _confirmFocusNode = FocusNode();
  List<Contact> _users = [];
  int? _groupValue;
  Device? _selectedDevice;
  UserProfile? _selectedUser;

  @override
  void initState() {
    super.initState();
    _setUsers();
  }

  @override
  void dispose() {
    _confirmFocusNode.dispose();
    super.dispose();
  }

  void _setUsers() async {
    var users = await getContacts(
            idList: widget.inputUsers?.map((e) => e.id).toList()) ??
        [];
    final exclude = widget.exclude;
    users = exclude != null
        ? users.where((e) => !(exclude.contains(e.id))).toList()
        : users;
    if (widget.userFilter != null) {
      users = users.where((e) => widget.userFilter?.call(e) ?? true).toList();
    }
    if (mounted) {
      setState(() {
        _users = users;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_users.isEmpty) {
      return _noAvailableUser;
    }
    if (!widget.enableScroll) {
      return Column(
        children: [
          Expanded(child: _pagedListView),
          const SizedBox(height: 8),
          if (!_simpleSelect) _bottomButton(context),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(child: _groupUserList),
        const SizedBox(height: 8),
        if (!_simpleSelect) _bottomButton(context),
      ],
    );
  }

  Widget get _noAvailableUser {
    final tr = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.titleLarge;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 64),
        Text(tr.noUserAvailableDetailsText, style: style),
        const SizedBox(height: 64),
        BaseInputButton(
          shrinkWrap: true,
          child: Text(tr.ok),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  bool get _simpleSelect {
    return (((Pst.enableTV ?? false) || !widget.enableScroll) &&
        widget.chooseOnlyOneUser);
  }

  Widget _bottomButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2, right: 15, bottom: 10),
      alignment: Alignment.bottomRight,
      child: _selectButton(context),
    );
  }

  /// Flip the selected state.
  void _flipSelectedState(int index, Device? device) async {
    final oldValue = _selectedIndexMap[index] ?? false;
    final newValue = !oldValue;
    setState(() {
      if (widget.chooseOnlyOneUser) {
        _groupValue = newValue ? index : null;
      }
      _selectedIndexMap[index] = newValue;
      _selectedDevice = newValue ? device : null;
    });
    // If selected the expected items, move focus to confirm button.
    if (newValue &&
        !_simpleSelect &&
        ((widget.chooseOnlyOneDevice && device != null) ||
            widget.chooseOnlyOneUser)) {
      _confirmFocusNode.requestFocus();
    }
  }

  Widget _getRadioButton(int index, {void Function(int?)? chooseOnlyOne}) {
    if (chooseOnlyOne != null || widget.chooseOnlyOneUser) {
      return Radio(
        value: index,
        groupValue: _groupValue,
        onChanged: (int? value) {
          setState(() {
            _groupValue = value;
          });
          chooseOnlyOne?.call(value);
          if (widget.chooseOnlyOneUser && !widget.chooseOnlyOneDevice) {
            _confirmFocusNode.requestFocus();
          }
        },
      );
    }
    return Checkbox(
      shape: const CircleBorder(),
      value: _selectedIndexMap[index] ?? false,
      onChanged: (value) {
        setState(() {
          _selectedIndexMap[index] = value!;
        });
      },
    );
  }

  List<Device> _getUserDevices(Contact user) {
    final peers =
        user.devices.where((d) => d.id != Pst.selfDevice?.id).toList();
    if (peers.isEmpty) {
      return [];
    }
    final filteredPeers = <Device>[];
    final filterFn = widget.deviceFilter;
    if (filterFn == null) {
      filteredPeers.addAll(peers);
    } else {
      for (var peer in peers) {
        if (filterFn(peer)) filteredPeers.add(peer);
      }
    }
    return filteredPeers;
  }

  Widget? _getUserDeviceListPopup(
    int index,
    Contact user, {
    Widget? child,
  }) {
    final tr = AppLocalizations.of(context);
    final filteredPeers = _getUserDevices(user);
    if (filteredPeers.isEmpty) {
      return null;
    }
    return PopupMenuButton<Device>(
      onSelected: (Device peer) {
        _flipSelectedState(index, peer);
        if (_simpleSelect) {
          _handleSelectOnlyOneUser();
        }
      },
      tooltip: tr.selectADeviceText,
      offset: const Offset(0, 50),
      child: child ?? const Icon(Icons.more_vert_rounded),
      itemBuilder: (context) {
        return filteredPeers.map((peer) {
          return PeerPopupMenuItem(peer: peer);
        }).toList();
      },
    );
  }

  Widget? _getUserChild(int index, Contact user, {Device? device}) {
    device ??= (_groupValue == index) ? _selectedDevice : null;
    final child = ListTile(
      contentPadding: widget.enableScroll ? null : const EdgeInsets.all(0),
      selected: _groupValue == index,
      title: Text(user.name),
      subtitle: device != null
          ? Row(children: [
              Expanded(child: Text(device.hostname)),
              Text(device.address),
            ])
          : null,
    );
    if (widget.chooseOnlyOneDevice &&
        widget.chooseOnlyOneUser &&
        device == null) {
      return _getUserDeviceListPopup(index, user, child: child);
    }
    return child;
  }

  Widget _getUserCard(int index, Contact user, {Device? device}) {
    final userChild = _getUserChild(
      index,
      user,
      device: device,
    );
    if (userChild == null) {
      return Container();
    }

    return UserCard(
      noGradient: true,
      leading: _simpleSelect ? null : _getRadioButton(index),
      user: user,
      onTap: widget.chooseOnlyOneDevice
          ? null
          : () {
              _flipSelectedState(index, null);
              if (_simpleSelect) {
                _handleSelectOnlyOneUser();
              }
            },
      child: userChild,
    );
  }

  Widget _getDeviceCard(int index, Device device) {
    return UserCard(
      noGradient: true,
      avatarChild: getOsOnlineIcon(device.os, device.isOnline),
      leading: _getRadioButton(
        index,
        chooseOnlyOne: (value) {
          _selectedDevice = device;
          _confirmFocusNode.requestFocus();
        },
      ),
      child: Row(
        children: [
          Expanded(child: Text(device.hostname)),
          Text(device.address),
        ],
      ),
      onTap: () {
        _flipSelectedState(index, device);
      },
    );
  }

  Widget _getUserDeviceCards(Contact user) {
    final filteredPeers = _getUserDevices(user);
    if (filteredPeers.isEmpty) {
      return Card(child: Text("No device is avaibale"));
    }
    return ListView.builder(
      controller: ScrollController(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        if (index == 0) {
          return ListTile(
            title: Text(user.name),
            subtitle: Text(user.username),
          );
        }
        final peer = filteredPeers[index - 1];
        return _getDeviceCard(index, peer);
      },
      itemCount: filteredPeers.length + 1,
    );
  }

  Widget get _groupUserList {
    if (_users.isEmpty) {
      return Container();
    }
    if (_users.length == 1 && widget.chooseOnlyOneDevice) {
      _selectedUser = _users[0];
      return _getUserDeviceCards(_users[0]);
    }
    if (widget.enableScroll) {
      return _allUsersListView;
    }
    return _pagedListView;
  }

  Widget get _pagedListView {
    return PagedList(
      itemBuilder: ({
        required index,
        required itemHeight,
        required itemWidth,
      }) {
        final user = _users[index];
        return Container(
          padding: const EdgeInsets.all(4),
          child: _getUserCard(
            index,
            user,
          ),
        );
      },
      itemsCount: _users.length,
    );
  }

  Widget get _allUsersListView {
    return ListView.builder(
      controller: ScrollController(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        final user = _users[index];
        return _getUserCard(index, user);
      },
      itemCount: _users.length,
    );
  }

  Widget _selectButton(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return BaseInputButton(
      focusNode: _confirmFocusNode,
      shrinkWrap: true,
      child: Text(
        widget.selectButtonText ?? tr.confirmText,
        textWidthBasis: TextWidthBasis.parent,
      ),
      onPressed: () {
        if (widget.chooseOnlyOneUser) {
          _handleSelectOnlyOneUser();
          return;
        }
        _handleSelectUsers();
      },
    );
  }

  void _handleSelectOnlyOneUser() {
    final tr = AppLocalizations.of(context);
    final selected = _groupValue;
    if (selected == null && _selectedUser == null) {
      SnackbarWidget.e(tr.pleaseSelectOneUserText).show(context);
      return;
    }
    if (widget.chooseOnlyOneDevice) {
      if (_selectedDevice == null) {
        SnackbarWidget.e(tr.pleaseSelectOneDeviceText).show(context);
        return;
      }
    }
    final user = _selectedUser ?? _users[selected!];
    widget.onSelected([user], device: _selectedDevice);
    return;
  }

  void _handleSelectUsers() {
    final tr = AppLocalizations.of(context);
    final selfUser = Pst.selfUser;
    final selectedUsers = <UserProfile>[];
    if (selfUser == null) {
      SnackbarWidget.e(tr.selfUserNotFoundError).show(context);
      return;
    }
    for (var k in _selectedIndexMap.keys) {
      if (_selectedIndexMap[k] == true) {
        final user = _users[k];
        selectedUsers.add(user);
      }
    }
    widget.onSelected(selectedUsers);
  }
}
