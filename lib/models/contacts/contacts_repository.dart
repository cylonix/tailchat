// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'contact.dart';
import 'contacts_storage.dart';
import 'device.dart';

class ContactsRepository {
  final ContactsStorage _storage;

  ContactsRepository(this._storage);

  static Future<ContactsRepository> getInstance() async {
    final storage = await ContactsStorage.getInstance();
    return ContactsRepository(storage);
  }

  Future<int> getContactCount() => _storage.getContactCount();
  Future<int> getDeviceCount() => _storage.getDeviceCount();

  Future<Contact?> getContact(String? id) => _storage.getContact(id);
  Future<Device?> getDevice(String? id) => _storage.getDevice(id);
  Future<List<Contact>> getContacts({List<String>? idList}) =>
      _storage.getContacts(idList: idList);
  Future<List<Device>?> getDevices(String? userID) async =>
      (await getContact(userID))?.devices;
  Future<void> addContact(Contact contact, {bool mergeIfExists = false}) =>
      _storage.addContact(
        contact,
        mergeIfExists: mergeIfExists,
      );
  Future<void> updateContact(Contact contact) =>
      _storage.updateContact(contact);
  Future<void> deleteContact(String id) => _storage.deleteContact(id);
  Future<void> deleteDevice(String id) => _storage.deleteDevice(id);
  Future<void> addDevice(Device device) => _storage.addDevice(device);
  Future<void> updateDevice(Device device) => _storage.updateDevice(device);
}
