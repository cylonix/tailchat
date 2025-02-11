// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../../api/contacts.dart';
import '../../models/alert.dart';
import '../../models/contacts/contact.dart';
import '../../models/contacts/device.dart';
import '../../utils/utils.dart';
import '../alert_chip.dart';
import 'device_dialog.dart';
import 'user_profile_input.dart';

class ContactDialog extends StatefulWidget {
  final Contact? contact;
  final List<Device>? devices;

  const ContactDialog({
    super.key,
    this.contact,
    this.devices,
  });

  @override
  State<ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<ContactDialog> {
  List<Device> _devices = [];
  String? _username, _name, _profileUrl;
  Alert? _alert;

  @override
  void initState() {
    super.initState();
    _username = widget.contact?.username;
    _name = widget.contact?.name;
    _profileUrl = widget.contact?.profileUrl;
    _devices = widget.contact?.devices.toList() ?? widget.devices ?? [];
  }

  @override
  void didUpdateWidget(ContactDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contact?.id != widget.contact?.id) {
      _username = widget.contact?.username;
      _name = widget.contact?.name;
      _profileUrl = widget.contact?.profileUrl;
    }
  }

  void _handleProfileChange(String username, String name, String profileUrl) {
    setState(() {
      _username = username;
      _name = name;
      _profileUrl = profileUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.contact == null ? 'Add Contact' : 'Edit Contact'),
      content: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              minWidth: isMediumScreen(context) ? 600 : 350,
            ),
            child: Column(
              spacing: 16,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_alert != null) AlertChip(_alert!),
                UserProfileInput(
                  usernameReadOnly: widget.contact != null,
                  initialUsername: widget.contact?.username,
                  initialName: widget.contact?.name,
                  initialProfileUrl: widget.contact?.profileUrl,
                  onChanged: _handleProfileChange,
                ),
                SizedBox(
                  width: double.infinity,
                  child: Card(
                    margin: const EdgeInsets.all(0),
                    child: Column(
                      spacing: 8,
                      children: [
                        ListTile(
                          title: Text('Devices'),
                          trailing: TextButton(
                            onPressed: _contactID != null ? _addDevice : null,
                            child: Text('Add Device'),
                          ),
                        ),
                        ..._buildDevicesList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: _saveContact,
          child: Text('Save'),
        ),
      ],
    );
  }

  List<Widget> _buildDevicesList() {
    return _devices.map((device) {
      return ListTile(
        title: Text(device.hostname),
        subtitle: Text('Port: ${device.port}'),
        trailing: IconButton(
          icon: Icon(Icons.delete),
          onPressed: () => _removeDevice(device),
        ),
      );
    }).toList();
  }

  String? get _contactID {
    return _username == null ? null : Contact.generateID(_username!);
  }

  void _addDevice() {
    showDialog(
      context: context,
      builder: (context) => DeviceDialog(contact: _contactID!),
    ).then((device) {
      if (device != null) {
        setState(() {
          _devices.add(device);
        });
      }
    });
  }

  void _removeDevice(Device device) {
    setState(() {
      _devices.remove(device);
    });
  }

  void _saveContact() async {
    final username = _username;

    // Validate and save contact
    if (username == null || username.isEmpty) {
      setState(() {
        _alert = Alert("Invalid username");
      });
      return;
    }

    // Check if username already exists.
    if (widget.contact == null) {
      if (await contactExists(Contact.generateID(username))) {
        if (mounted) {
          setState(() {
            _alert = Alert("Contact with $username exists.");
          });
        }
        return;
      }
    }

    for (int i = 0; i < _devices.length; i++) {
      _devices[i].userID = _contactID!;
    }
    final contact = Contact(
      username: _username!,
      name: (_name?.isEmpty ?? true) ? null : _name!,
      profileUrl: (_profileUrl?.isEmpty ?? true) ? null : _profileUrl!,
      devices: _devices,
    );

    try {
      await (widget.contact == null
          ? addContact(contact)
          : updateContact(contact));
      if (mounted) {
        toast(context, "Contact ${contact.name} saved.");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _alert = Alert("Failed to save contact: $e");
        });
      }
      return;
    }

    // Save success.
    if (mounted) {
      Navigator.pop(context, contact);
    }
  }
}
