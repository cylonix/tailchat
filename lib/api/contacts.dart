// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:event_bus/event_bus.dart';
import '../models/contacts/contact.dart';
import '../models/contacts/contacts_repository.dart';
import '../models/contacts/device.dart';
import '../models/contacts/user_profile.dart';

ContactsRepository? _repository;
EventBus contactsEventBus = EventBus();

enum ContactsEventType {
  addContact,
  addDevice,
  updateContact,
  updateDevice,
  deleteContact,
  deleteDevice,
}

class ContactsEvent {
  final ContactsEventType eventType;
  final Contact? contact;
  final Device? device;
  final String? contactID;
  final String? deviceID;
  ContactsEvent({
    required this.eventType,
    this.contactID,
    this.deviceID,
    this.contact,
    this.device,
  });
  @override
  String toString() {
    return '${eventType.name} contact_id=$contactID '
        'device_id=$deviceID $contact $device';
  }
}

Future<Contact?> getContact(String? id) async {
  if (id == null || id.isEmpty) {
    return null;
  }
  _repository ??= await ContactsRepository.getInstance();
  return await _repository?.getContact(id);
}

Future<Device?> getDevice(String? id) async {
  if (id == null || id.isEmpty) {
    return null;
  }
  _repository ??= await ContactsRepository.getInstance();
  return await _repository?.getDevice(id);
}

Future<UserProfile?> getUser(String? id) async {
  return await getContact(id);
}

Future<List<Device>?> getUserDevices(String? id) async {
  return (await getContact(id))?.devices;
}

Future<List<Contact>?> getContacts({
  List<String>? idList,
  int? offset,
  int? limit,
}) async {
  // Paging is not yet supported.
  _repository ??= await ContactsRepository.getInstance();
  return await _repository?.getContacts(idList: idList);
}

Future<int> getContactCount() async {
  _repository ??= await ContactsRepository.getInstance();
  return (await _repository?.getContactCount()) ?? 0;
}

Future<int> getDeviceCount() async {
  _repository ??= await ContactsRepository.getInstance();
  return (await _repository?.getDeviceCount()) ?? 0;
}

Future<void> addContact(Contact contact) async {
  _repository ??= await ContactsRepository.getInstance();
  await _repository?.addContact(contact);
  contactsEventBus.fire(
    ContactsEvent(
      eventType: ContactsEventType.addContact,
      contact: contact,
      contactID: contact.id,
    ),
  );
}

Future<void> updateContact(Contact contact) async {
  _repository ??= await ContactsRepository.getInstance();
  await _repository?.updateContact(contact);
  contactsEventBus.fire(
    ContactsEvent(
      eventType: ContactsEventType.updateContact,
      contact: contact,
      contactID: contact.id,
    ),
  );
}

Future<void> updateDevice(Device device) async {
  _repository ??= await ContactsRepository.getInstance();
  await _repository?.updateDevice(device);
  final contact = await getContact(device.userID);
  contactsEventBus.fire(
    ContactsEvent(
      eventType: ContactsEventType.updateDevice,
      contact: contact,
      device: device,
      deviceID: device.id,
      contactID: device.userID,
    ),
  );
}

Future<void> deleteContact(String id) async {
  _repository ??= await ContactsRepository.getInstance();
  await _repository?.deleteContact(id);
  contactsEventBus.fire(
    ContactsEvent(
      eventType: ContactsEventType.deleteContact,
      contactID: id,
    ),
  );
}

Future<void> addDevice(Device device) async {
  _repository ??= await ContactsRepository.getInstance();
  await _repository?.addDevice(device);
  contactsEventBus.fire(
    ContactsEvent(
      eventType: ContactsEventType.addDevice,
      device: device,
      deviceID: device.id,
      contactID: device.userID,
    ),
  );
}

Future<void> deleteDevice(String id) async {
  _repository ??= await ContactsRepository.getInstance();
  await _repository?.deleteDevice(id);
  contactsEventBus.fire(
    ContactsEvent(
      eventType: ContactsEventType.deleteDevice,
      deviceID: id,
    ),
  );
}

Future<bool> contactExists(String id) async {
  final contact = await getContact(id);
  return contact != null;
}

Future<bool> deviceExists(String id) async {
  final device = await getDevice(id);
  return device != null;
}
