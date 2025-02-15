// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'package:tailchat/api/contacts.dart';
import '../../models/alert.dart';
import '../../models/contacts/contact.dart';
import '../../models/contacts/device.dart';
import '../../utils/utils.dart';
import '../../utils/logger.dart';
import '../alert_chip.dart';
import 'user_avatar.dart';
import 'user_profile_input.dart';

class HostnameChangeDialog extends StatefulWidget {
  final Contact currentContact;
  final Device currentDevice;
  final Device newDevice;

  const HostnameChangeDialog({
    super.key,
    required this.currentContact,
    required this.currentDevice,
    required this.newDevice,
  });

  @override
  State<HostnameChangeDialog> createState() => _HostnameChangeDialogState();
}

class _HostnameChangeDialogState extends State<HostnameChangeDialog> {
  static final _logger = Logger(tag: "HostnameChangeDialog");
  final _formKey = GlobalKey<FormState>();
  final _statusController = TextEditingController();
  List<Contact> _contacts = [];
  Contact? _selectedContact;
  String? _username, _name, _profileUrl;
  Alert? _alert;
  bool _createNew = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _username = widget.currentContact.username;
    _name = widget.currentContact.name;
    _profileUrl = widget.currentContact.profileUrl ?? '';
    _statusController.text = widget.currentContact.status ?? '';
  }

  void _loadContacts() async {
    final contacts = (await getContacts()) ?? [];
    if (mounted) {
      setState(() {
        _contacts = contacts;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Network Change Detected'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text('New hostname detected: ${widget.newDevice.hostname}'),
              Text("Current device: ${widget.currentDevice.hostname}"),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Create new contact'),
                subtitle: Text(
                  'Otherwise update an existing contact'
                  '(${_contacts.length})',
                ),
                value: _createNew,
                onChanged: (value) => setState(() => _createNew = value),
              ),
              if (_alert != null) AlertChip(_alert!),
              if (_createNew) ...[
                UserProfileInput(
                  usernameMustChange: true,
                  initialUsername: _username,
                  initialName: _name,
                  initialProfileUrl: _profileUrl,
                  onChanged: (username, name, profileUrl) => {
                    setState(() {
                      _username = username;
                      _name = name;
                      _profileUrl = profileUrl;
                    })
                  },
                ),
                TextField(
                  controller: _statusController,
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
              ],
              if (!_createNew && _contacts.isNotEmpty) _contactSelectMenu,
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _handleSave(context),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget get _contactSelectMenu {
    return Padding(
      padding: EdgeInsets.only(left: 16),
      child: DropdownMenu<Contact>(
        enableFilter: true,
        requestFocusOnTap: true,
        leadingIcon: const Icon(Icons.account_circle),
        label: const Text('Select an existing contact'),
        inputDecorationTheme: InputDecorationTheme(
          constraints: const BoxConstraints(minWidth: 240),
          filled: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 4,
            horizontal: 8,
          ),
        ),
        onSelected: (value) {
          setState(() {
            _selectedContact = value;
          });
        },
        dropdownMenuEntries: _contacts
            .map<DropdownMenuEntry<Contact>>(
              (c) => DropdownMenuEntry<Contact>(
                value: c,
                label: c.username,
                labelWidget: Container(
                  constraints: const BoxConstraints(minWidth: 200),
                  child: Text(c.username),
                ),
                leadingIcon: UserAvatar(user: c, radius: 16),
                trailingIcon: _selectedContact?.id == c.id
                    ? Icon(Icons.check, size: 16)
                    : null,
              ),
            )
            .toList(),
      ),
    );
  }

  void _handleSave(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    if (_createNew) {
      _logger.d("Saving a new contact $_username");
      final newContact = Contact(
        username: _username!,
        name: (_name?.isEmpty ?? true) ? null : _name,
        profileUrl: (_profileUrl?.isEmpty ?? true) ? null : _profileUrl,
        status: _statusController.text.isEmpty ? null : _statusController.text,
        devices: [widget.newDevice],
      );
      try {
        await addContact(newContact);
        if (context.mounted) {
          toast(context, "Contact ${newContact.name} added.");
        }
      } catch (e) {
        _logger.e("Failed to save new contact: $e");
        if (context.mounted) {
          setState(() {
            _alert = Alert("Failed to save new contact: $e");
          });
        }
        return;
      }
      if (context.mounted) {
        Navigator.pop(context, newContact);
      }
      return;
    }
    if (_selectedContact == null) {
      setState(() {
        _alert = Alert("Please select a contact from the existing contacts.");
      });
      return;
    }
    final updatedContact = _selectedContact!..devices.add(widget.newDevice);
    try {
      await updateContact(updatedContact);
      if (context.mounted) {
        toast(context, "Contact ${updatedContact.name} updated.");
      }
    } catch (e) {
      _logger.e("Failed to save contact: $e");
      if (context.mounted) {
        setState(() {
          _alert = Alert("Failed to save contact: $e");
        });
      }
      return;
    }
    if (context.mounted) {
      Navigator.pop(context, updatedContact);
    }
  }

  @override
  void dispose() {
    _statusController.dispose();
    super.dispose();
  }
}
