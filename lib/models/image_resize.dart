// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart';

void _decodeIsolate(ImageResize r) {
  final image = decodeImage(r.file.readAsBytesSync())!;
  final thumbnail = copyResize(image, width: r.width ?? 120);
  r.sendPort.send(thumbnail);
}

class ImageResize {
  final File file;
  final SendPort sendPort;
  int? width;
  ImageResize({required this.file, required this.sendPort, this.width});
}

Future<Uint8List> resizeImage(File file, {int? width}) async {
  final receivePort = ReceivePort();
  await Isolate.spawn(
    _decodeIsolate,
    ImageResize(
      file: file,
      sendPort: receivePort.sendPort,
      width: width,
    ),
  );
  final image = await receivePort.first as Image;
  return Uint8List.fromList(encodePng(image));
}
