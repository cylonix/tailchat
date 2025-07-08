// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailchat/utils/utils.dart';
import 'package:tailchat/utils/logger.dart';
import 'contact.dart';
import 'device.dart';

class ContactsStorage {
  static final _logger = Logger(tag: "ChatStorage");
  static const String _storageKey = 'contacts';
  final SharedPreferences _prefs;
  List<Contact>? _cachedContacts;

  ContactsStorage(this._prefs);

  static Future<ContactsStorage> getInstance() async {
    final prefs = await SharedPreferences.getInstance();
    return ContactsStorage(prefs);
  }

  Future<Contact?> getContact(String? id) async {
    if (id == null) return null;
    final contacts = await getContacts();
    return contacts.firstWhereOrNull((c) => c.id == id);
  }

  Future<Device?> getDevice(String? id) async {
    if (id == null) return null;
    final contacts = await getContacts();
    return contacts
        .expand((c) => c.devices)
        .firstWhereOrNull((d) => d.id == id);
  }

  Future<List<Contact>> _getContacts() async {
    final String? contactsJson = _prefs.getString(_storageKey);
    if (contactsJson == null) return [];
    List<dynamic> decoded = [];
    try {
      decoded = jsonDecode(contactsJson);
    } catch (e) {
      _logger.e(
        "Failed to decode saved contacts to json: "
        "${contactsJson.shortString(300)}: $e",
      );
    }
    return decoded
        .map((json) {
          try {
            var contact = Contact.fromJson(json);
            contact.devices = contact.devices.map((d) {
              d.isOnline = false;
              return d;
            }).toList();
            return contact;
          } catch (e) {
            _logger.e(
              "Failed to decode json to contact: "
              "${jsonEncode(json).shortString(300)}: $e",
            );
          }
          return null;
        })
        .nonNulls
        .toList();
  }

  Future<List<Contact>> getContacts({List<String>? idList}) async {
    final contacts = _cachedContacts ?? await _getContacts();
    if (idList == null) {
      return contacts;
    }
    return contacts.where((e) => idList.contains(e.id)).toList();
  }

  Future<int> getContactCount() async {
    final contacts = await getContacts();
    return contacts.length;
  }

  Future<int> getDeviceCount() async {
    final contacts = await getContacts();
    int count = 0;
    for (var contact in contacts) {
      count += contact.devices.length;
    }
    return count;
  }

  Future<void> saveContacts(List<Contact> contacts) async {
    final String encoded = jsonEncode(
      contacts.map((contact) => contact.toJson()).toList(),
    );
    _cachedContacts = contacts;
    await _prefs.setString(_storageKey, encoded);
  }

  Future<void> addContact(Contact contact, {bool mergeIfExists = false}) async {
    final contacts = await getContacts();
    if (contacts.any((c) => c.id == contact.id)) {
      if (mergeIfExists) {
        final index = contacts.indexWhere((c) => c.id == contact.id);
        final current = contacts[index];
        for (var device in contact.devices) {
          if (current.devices.any((d) => d.id == device.id)) {
            // Device already exists, update it
            final deviceIndex =
                current.devices.indexWhere((d) => d.id == device.id);
            current.devices[deviceIndex] = device;
          } else {
            // Add new device
            current.devices.add(device);
          }
        }
        contacts[index] = current; // Replace with updated contact
        await saveContacts(contacts);
        _logger.d("Contact updated: ${contact.name}");
        return;
      }
      throw Exception("contact exists");
    }
    contacts.add(contact);
    await saveContacts(contacts);
  }

  Future<void> updateContact(Contact contact) async {
    final contacts = await getContacts();
    final index = contacts.indexWhere((c) => c.id == contact.id);
    if (index != -1) {
      contacts[index] = contact;
      await saveContacts(contacts);
    } else {
      throw Exception("contact does not exist");
    }
  }

  Future<void> deleteContact(String id) async {
    final contacts = await getContacts();
    contacts.removeWhere((c) => c.id == id);
    await saveContacts(contacts);
  }

  Future<void> addDevice(Device device) async {
    final d = await getDevice(device.id);
    if (d != null) {
      throw Exception("device exists");
    }
    final contacts = await getContacts();
    final c = contacts.firstWhere((c) => c.id == device.userID);
    c.devices.add(device);
    _logger.d(
      "Device added to ${c.name}: ${device.hostname}. "
      "Total devices: ${c.devices.length}",
    );
    await saveContacts(contacts);
  }

  Future<void> deleteDevice(String id) async {
    final device = await getDevice(id);
    if (device == null) {
      return;
    }
    final contacts = await getContacts();
    final index = contacts.indexWhere((c) => c.id == device.userID);
    if (index < 0) {
      throw Exception("cannot find contact");
    }
    contacts[index].devices.removeWhere((d) => d.id == id);
    await saveContacts(contacts);
  }

  Future<void> updateDevice(Device device) async {
    final contacts = await getContacts();
    final contact = contacts.firstWhere((c) => c.id == device.userID);
    final index = contact.devices.indexWhere((d) => d.id == device.id);
    if (index != -1) {
      contact.devices[index] = device;
      await saveContacts(contacts);
    } else {
      throw Exception("device does not exist");
    }
  }
}
