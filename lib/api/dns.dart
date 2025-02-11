// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import '../utils/logger.dart';
import '../utils/utils.dart';

final _logger = Logger(tag: "DNS");
Future<String> resolveHostname(String address) async {
  try {
    _logger.i("Looking up $address");
    var v = InternetAddress.tryParse(address);
    if (v == null) {
      throw ("Invalid internet address: $address");
    }

    // Reverse() only works on desktop for now.
    if (isDesktop()) {
      v = await v.reverse();
      _logger.d("Lookup result is $v");
      return v.host;
    }

    // Send udp query to do the reverse lookup for mobile platforms.
    final result = await udpReverseLookup(address);
    _logger.d("UDP lookup result is $result");
    return result;
  } catch (e) {
    _logger.w('DNS resolution failed for $address: $e');
    return address;
  }
}

Future<String?> resolveV4Address(String hostname) async {
  try {
    _logger.i("Looking up $hostname");
    final result = await InternetAddress.lookup(hostname);
    _logger.d("Lookup result is $result");
    if (result.isEmpty) return null;
    for (var r in result) {
      if (r.type == InternetAddressType.IPv4) {
        return r.address;
      }
    }
  } catch (e) {
    _logger.w('DNS resolution failed for $hostname: $e');
  }
  return null;
}

bool isFQDN(String? hostname) {
  return (hostname ?? "").split(".").length > 1;
}

bool isIPv4Address(String value) {
  try {
    return InternetAddress(value).type == InternetAddressType.IPv4;
  } catch (_) {
    return false;
  }
}

Future<String> udpReverseLookup(String address) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  final completer = Completer<String>();

  try {
    final query = _buildDNSQuery(address);
    socket.send(query, InternetAddress('100.100.100.100'), 53);

    socket.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram != null) {
          try {
            final hostname = _parseDNSResponse(datagram.data);
            if (!completer.isCompleted) {
              completer.complete(hostname ?? address);
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.complete(address);
            }
          }
        }
      }
    });

    return await completer.future.timeout(
      const Duration(seconds: 1),
      onTimeout: () => address,
    );
  } finally {
    socket.close();
  }
}

Uint8List _buildDNSQuery(String address) {
  final builder = BytesBuilder();
  final queryId = 0x1234;

  // Header
  builder
    ..add([queryId >> 8, queryId & 0xFF]) // ID
    ..add([0x01, 0x00]) // Flags
    ..add([0x00, 0x01]) // Questions
    ..add([0x00, 0x00]) // Answers
    ..add([0x00, 0x00]) // Authority RRs
    ..add([0x00, 0x00]); // Additional RRs

  // Query name
  final parts = address.split('.').reversed.toList();
  parts.add('in-addr');
  parts.add('arpa');

  for (var part in parts) {
    builder
      ..addByte(part.length)
      ..add(part.codeUnits);
  }

  builder
    ..addByte(0) // Terminator
    ..add([0x00, 0x0c]) // Type PTR
    ..add([0x00, 0x01]); // Class IN

  return builder.toBytes();
}

class _NameResult {
  final String name;
  final int bytesRead;
  _NameResult(this.name, this.bytesRead);
}

_NameResult _readName(Uint8List data, int position) {
  var result = '';
  var bytesRead = 0;
  var current = position;

  while (current < data.length) {
    final length = data[current];
    if (length == 0) {
      bytesRead++;
      break;
    }

    // Handle compression pointer
    if ((length & 0xC0) == 0xC0) {
      if (current + 1 >= data.length) break;
      final offset = ((length & 0x3F) << 8) | data[current + 1];
      final compressed = _readName(data, offset);
      result += (result.isEmpty ? '' : '.') + compressed.name;
      bytesRead += 2;
      break;
    }

    current++;
    bytesRead++;

    if (current + length > data.length) break;

    if (result.isNotEmpty) result += '.';
    result += String.fromCharCodes(data.sublist(current, current + length));

    current += length;
    bytesRead += length;
  }
  _logger.d("UDP: result: $result");

  return _NameResult(result, bytesRead);
}

String _hexDump(Uint8List data, {int offset = 0, int? length}) {
  final len = length ?? data.length;
  final buffer = StringBuffer();
  const bytesPerLine = 16;

  for (var i = 0; i < len; i += bytesPerLine) {
    // Write offset
    buffer.write('${(offset + i).toRadixString(16).padLeft(8, '0')}  ');

    // Write hex values
    final lineEnd = math.min(i + bytesPerLine, len);
    for (var j = i; j < lineEnd; j++) {
      buffer.write('${data[j].toRadixString(16).padLeft(2, '0')} ');
      if ((j + 1) % 8 == 0 && (j + 1) % 16 != 0) buffer.write(' ');
    }

    // Pad remaining hex area if incomplete line
    if (lineEnd < i + bytesPerLine) {
      final padding = (i + bytesPerLine - lineEnd) * 3;
      buffer.write(' ' * padding);
      if (lineEnd < i + 8) buffer.write(' ');
    }

    // Write ASCII representation
    buffer.write('  |');
    for (var j = i; j < lineEnd; j++) {
      final byte = data[j];
      buffer.write(byte >= 32 && byte <= 126 ? String.fromCharCode(byte) : '.');
    }
    buffer.write('|\n');
  }

  return buffer.toString();
}

String? _parseDNSResponse(Uint8List data) {
  for (var line in _hexDump(data).split("\n")) {
    _logger.d("UDP: response: $line");
  }

  if (data.length < 12) return null;
  var position = 12;

  // Skip question
  final question = _readName(data, position);
  position += question.bytesRead + 4;

  if (position + 2 > data.length) return null;

  // Read answer NAME field
  final answer = _readName(data, position);
  position += answer.bytesRead;

  // Skip TYPE, CLASS, TTL
  position += 8;

  if (position + 2 > data.length) return null;

  final rdLength = (data[position] << 8) | data[position + 1];
  position += 2;

  if (position + rdLength > data.length) {
    _logger.d(
      "UDP: data length $rdLength from $position. "
      "Out of bound: ${data.length}",
    );
    return null;
  }

  final ptr = _readName(data, position);
  return ptr.name.isNotEmpty ? ptr.name : null;
}
