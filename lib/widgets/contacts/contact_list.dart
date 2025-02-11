// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';

// Please keep the imports in alphabetic order
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../api/config.dart';
import '../../api/contacts.dart';
import '../../models/config/config_change_event.dart';
import '../../models/contacts/contact.dart';
import '../../models/contacts/user_profile.dart';
import '../../utils/logger.dart';
import '../../utils/utils.dart';
import '../session_feature_button.dart';
import '../top_row.dart';
import 'contact_details_page.dart';
import 'contact_dialog.dart';

class ContactList extends StatefulWidget {
  final void Function(Widget) onSelected;
  final bool showSideBySide;
  final bool isTV;
  const ContactList({
    super.key,
    required this.onSelected,
    this.showSideBySide = false,
    this.isTV = false,
  });

  @override
  State<ContactList> createState() => _ContactListState();
}

class _ContactListState extends State<ContactList> {
  static final _logger = Logger(tag: "ContactList");
  static const _pageSize = 20;
  final _scrollController = ScrollController();
  StreamSubscription<SelfUserChangeEvent>? _configChangeSub;
  StreamSubscription<ContactsEvent>? _contactsEventSub;
  List<Contact> _contacts = [];
  UserProfile? _selfUser;
  bool _isLoading = false;
  int _currentPage = 0, _contactCount = 0, _deviceCount = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _selfUser = Pst.selfUser;
    _registerToConfigChangeEvents();
    _registerToContactsEvents();
    _scrollController.addListener(_onScroll);
    _loadContactAndDeviceCount();
    _loadMoreContacts();
  }

  @override
  void dispose() {
    _configChangeSub?.cancel();
    _contactsEventSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _registerToConfigChangeEvents() {
    final eventBus = Pst.eventBus;
    _configChangeSub = eventBus.on<SelfUserChangeEvent>().listen((event) {
      final newSelf = event.newSelfUser;
      if (_selfUser?.id != newSelf?.id) {
        _hasMore = true;
        _currentPage = 0;
        _contacts = [];
        _loadContactAndDeviceCount();
        _loadMoreContacts();
      }
      if (mounted) {
        setState(() {
          _selfUser = newSelf;
        });
      }
    });
  }

  void _registerToContactsEvents() {
    final eventBus = contactsEventBus;
    _contactsEventSub = eventBus.on<ContactsEvent>().listen((event) async {
      _logger.d("Contact updated.");
      var contactID = event.contactID;
      if (contactID == null) {
        if (event.deviceID != null) {
          contactID = _contacts
              .firstWhereOrNull(
                  (c) => c.devices.any((d) => d.id == event.deviceID))
              ?.id;
        }
      }
      if (contactID != null) {
        _logger.d("Contact update ID: $contactID");
        final index = _contacts.indexWhere((c) => c.id == contactID);
        if (index >= 0) {
          final contact = await getContact(contactID);
          if (mounted) {
            setState(() {
              if (contact == null) {
                _logger.d("Contact removed.");
                _contacts.removeAt(index);
              } else {
                _logger.d(
                  "Contact ${contact.username} updated."
                  "Device count: ${contact.devices.length}",
                );
                _contacts[index] = contact;
              }
            });
          }
        }
      }
    });
  }

  void _loadContactAndDeviceCount() async {
    _contactCount = await getContactCount();
    _deviceCount = await getDeviceCount();
  }

  Future<void> _loadMoreContacts() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final contacts = await getContacts(
        offset: _currentPage * _pageSize,
        limit: _pageSize,
      );

      setState(() {
        if (contacts?.isEmpty ?? true) {
          _hasMore = false;
        } else {
          _contacts.addAll(contacts!);
          _currentPage++;
        }
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreContacts();
    }
  }

  Widget _addContact({double? width}) {
    return SessionFeatureButton(
      mainAxisAlignment: MainAxisAlignment.center,
      width: width,
      enableFocusAwareSize: widget.isTV,
      icon: Icon(
        Icons.account_circle_outlined,
        size: widget.isTV ? 48 : 32,
        color: Colors.black,
      ),
      iconSize: widget.isTV ? 96 : 64,
      label: "Add Contact",
      onPressed: _showAddContactDialog,
    );
  }

  Widget get _topRow {
    final child = LayoutBuilder(
      builder: (_, constraints) {
        double? w = constraints.maxWidth / 3 - 16;
        if (w < 50) {
          w = null;
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _addContact(width: w),
          ],
        );
      },
    );
    return widget.isTV || useNavigationRail(context)
        ? TopRow(large: widget.isTV, child: child)
        : child;
  }

  Widget _contactCard(int index) {
    if (index >= _contacts.length) {
      if (!_isLoading) return const SizedBox();
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final contact = _contacts[index];
    var subtitle = contact.status != null ? '${contact.status}\n' : "";
    var hostnames = contact.devices.map((d) => d.hostname).join(', ');
    if (hostnames.length > 50) {
      hostnames = '${hostnames.shortString(50)}...';
    }
    subtitle = '$subtitle$hostnames';
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.circle,
          size: 12,
          color: contact.isOnline ? Colors.green : Colors.grey,
        ),
        title: Text(contact.name),
        subtitle: Text(subtitle),
        onTap: () => widget.onSelected(ContactDetailsPage(
          contact: contact,
          popOnDelete: showSideBySide(context),
        )),
      ),
    );
  }

  Widget get _contactList {
    return Column(children: [
      _topRow,
      const Divider(height: 1),
      const SizedBox(height: 4),
      ListTile(
        leading: Text("Users: $_contactCount"),
        trailing: Text("Devices: $_deviceCount"),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(8),
          controller: _scrollController,
          itemCount: _contacts.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) => _contactCard(index),
        ),
      ),
    ]);
  }

  Widget get _contactListForTV {
    final grids = LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final count = (maxWidth / 400).floor();
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          controller: _scrollController,
          itemCount: _contacts.length + (_hasMore ? 1 : 0),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            crossAxisCount: count,
            childAspectRatio: 3,
          ),
          itemBuilder: (context, index) => _contactCard(index),
        );
      },
    );
    return Container(color: Theme.of(context).canvasColor, child: grids);
  }

  void _showAddContactDialog() async {
    final contact = await showDialog<Contact>(
      context: context,
      builder: (context) => ContactDialog(),
    );
    {
      if (contact == null) {
        return;
      }
      if (mounted) {
        setState(() {
          _contacts.insert(0, contact);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.isTV
        ? Column(
            children: [
              _topRow,
              Expanded(child: _contactListForTV),
            ],
          )
        : _contactList;
  }
}
