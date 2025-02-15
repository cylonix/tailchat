// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../api/config.dart';
import '../../api/contacts.dart';
import '../../models/alert.dart';
import '../../models/contacts/contact.dart';
import '../../models/contacts/device.dart';
import '../../utils/logger.dart';
import '../../utils/utils.dart';
import '../alert_chip.dart';
import 'contact_dialog.dart';
import 'device_dialog.dart';
import 'user_profile_header.dart';

class ContactDetailsPage extends StatefulWidget {
  final Contact contact;
  final bool popOnDelete;

  const ContactDetailsPage({
    super.key,
    required this.contact,
    this.popOnDelete = true,
  });

  @override
  State<ContactDetailsPage> createState() => _ContactDetailsPageState();
}

class _ContactDetailsPageState extends State<ContactDetailsPage> {
  static final _logger = Logger(tag: "ContactDetails");
  late Contact _contact;
  StreamSubscription<ContactsEvent>? _contactsEventSub;
  Alert? _alert;

  @override
  void initState() {
    super.initState();
    _contact = widget.contact;
    _contactsEventSub =
        contactsEventBus.on<ContactsEvent>().listen(_handleContactsEvent);
  }

  @override
  void dispose() {
    _contactsEventSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(ContactDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contact.id != widget.contact.id) {
      _contact = widget.contact;
    }
  }

  void _handleContactsEvent(ContactsEvent event) {
    switch (event.eventType) {
      case ContactsEventType.update:
        final contact = event.contact;
        if (mounted && _contact.id == event.contactID && contact != null) {
          _logger.d("contact updated: $contact");
          setState(() {
            _contact = contact;
          });
        }
      default:
        // No-op
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editContact,
          ),
          if (_contact.id != Pst.selfUser?.id)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteContact,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            if (_alert != null) AlertChip(_alert!),
            _buildHeader(),
            _buildInfoCard(),
            _buildDevicesList(),
            _buildContactJson(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return UserProfileHeader(
      user: widget.contact,
      heroTag: 'contact-${_contact.id}',
    );
  }

  Widget _buildInfoCard() {
    final lastSeen = widget.contact.lastSeen;
    final lastSeenMsg = lastSeen != null ? timeago.format(lastSeen) : "never";
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: _contact.isOnline ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  _contact.isOnline ? 'Online' : 'Offline',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Last seen: $lastSeenMsg',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListTile(
            title: Text(
              'Devices',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addDevice,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _contact.devices.length,
          itemBuilder: (context, index) {
            final device = _contact.devices[index];
            final addr =
                device.address == device.hostname ? "" : "${device.address} ";
            final lastSeenMsg = device.isOnline
                ? ""
                : "\nLast seen: ${timeago.format(device.lastSeen)}";
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: Icon(
                  Icons.devices,
                  color: device.isOnline ? Colors.green : Colors.grey,
                ),
                title: Text(device.hostname),
                subtitle: Text('${addr}Port: ${device.port}$lastSeenMsg'),
                trailing: IconButton(
                  onPressed: () => _deleteDevice(device),
                  icon: const Icon(Icons.delete),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildContactJson() {
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    final prettyJson = encoder.convert(_contact.toJson());

    return ExpansionTile(
      title: const Text("Contact data"),
      children: [
        SingleChildScrollView(
          controller: ScrollController(),
          padding: const EdgeInsets.all(16.0),
          child: SelectableText(
            prettyJson,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  void _editContact() async {
    final result = await showDialog(
      context: context,
      builder: (context) => ContactDialog(contact: _contact),
    );
    if (result == null) {
      return;
    }
    if (mounted) {
      setState(() {
        _contact = result;
      });
    }
  }

  void _deleteContact() async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to delete ${_contact.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (delete ?? false) {
      try {
        await deleteContact(_contact.id);
        if (mounted) {
          toast(context, "Contact ${_contact.name} is deleted.");
          if (widget.popOnDelete) {
            Navigator.pop(context, 'delete'); // Pop with delete result
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _alert = Alert("Failed to delete contact: $e");
          });
        }
      }
    }
  }

  void _addDevice() async {
    showDialog(
      context: context,
      builder: (context) => DeviceDialog(contact: _contact.id),
    ).then((device) async {
      if (device == null) {
        return;
      }
      try {
        await addDevice(device);
        if (mounted) {
          setState(() {
            _contact.devices.add(device);
          });
          toast(context, "Device ${device.hostname} added.");
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _alert = Alert("Failed to add device: $e");
          });
        }
      }
    });
  }

  void _deleteDevice(Device device) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Delete Device'),
        content: Text('Are you sure you want to delete ${device.hostname}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (!(delete ?? false)) {
      return;
    }
    try {
      await deleteDevice(device.id);
      if (mounted) {
        toast(context, "Device ${device.hostname} is deleted.");
      }
      final contact = await getContact(_contact.id);
      if (contact == null) {
        if (context.mounted) {
          setState(() {
            _alert = Alert("Failed to get the updated contact");
          });
        }
        return;
      }
      if (context.mounted) {
        setState(() {
          _contact = contact;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _alert = Alert("Failed to delete device: $e");
        });
      }
    }
  }
}
