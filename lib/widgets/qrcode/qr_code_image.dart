// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:qr_flutter/qr_flutter.dart' as qrf;

import '../../gen/l10n/app_localizations.dart';
import '../../utils/utils.dart';
import '../base_input/button.dart';
import '../snackbar_widget.dart';

class QrCodeImage extends StatelessWidget {
  final String data;
  final Color backgroundColor;
  final Color qrBackgroundColor;
  final ImageProvider? image;
  final Widget? leading;
  final double qrImageSize;
  final double? height;
  final bool showSaveAsButton;
  final Function()? onSave;
  QrCodeImage(
    this.data, {
    super.key,
    this.backgroundColor = Colors.transparent,
    this.qrBackgroundColor = Colors.white,
    this.image,
    this.leading,
    this.showSaveAsButton = true,
    this.qrImageSize = 300,
    this.height,
    this.onSave,
  });
  final GlobalKey _globalKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        RepaintBoundary(
          key: _globalKey,
          child: Container(
            color: backgroundColor,
            height: height,
            width: qrImageSize + 20,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                if (leading != null) leading!,
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  color: qrBackgroundColor,
                  clipBehavior: Clip.antiAlias,
                  child: qrf.QrImageView(
                    size: qrImageSize,
                    data: data,
                    embeddedImage: image,
                    embeddedImageStyle: image != null
                        ? const qrf.QrEmbeddedImageStyle(size: Size(48, 48))
                        : null,
                    backgroundColor: qrBackgroundColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        showSaveAsButton
            ? BaseInputButton(
                width: qrImageSize,
                onPressed: () => _saveQrCodeImage(context),
                child: Text(_saveQrCodeImageLabel(context)),
              )
            : TextButton(
                child: Text(_saveQrCodeImageLabel(context)),
                onPressed: () => _saveQrCodeImage(context),
              ),
      ],
    );
  }

  String _saveQrCodeImageLabel(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return isMobile() ? tr.saveToGalleryText : tr.saveToFileText;
  }

  void _saveQrCodeImage(BuildContext context) {
    isMobile() ? _saveToGallery(context) : _saveToFile(context);
  }

  Future<ByteData?> _getQrImageData(BuildContext context) async {
    final ro = _globalKey.currentContext?.findRenderObject();
    final boundary = ro as RenderRepaintBoundary?;
    if (boundary == null) {
      return null;
    }
    final mq = MediaQuery.of(context);
    final image = await boundary.toImage(pixelRatio: mq.devicePixelRatio);
    return await image.toByteData(format: ui.ImageByteFormat.png);
  }

  void _saveToFile(BuildContext context) async {
    final picData = await _getQrImageData(context);
    final path = await FilePicker.platform.saveFile(type: FileType.image);
    if (path == null || picData == null) {
      return;
    }
    final exists = await File(path).exists();
    if (exists) {
      if (context.mounted) {
        final tr = AppLocalizations.of(context);
        if (!(await showAlertDialog(
              context,
              tr.confirmDialogTitle,
              tr.confirmToOverwriteFileText,
              okText: tr.yesButton,
            ) ??
            false)) {
          return;
        }
      }
    }
    try {
      await _writeToFile(picData, path);
      if (context.mounted) {
        final tr = AppLocalizations.of(context);
        SnackbarWidget.s(tr.imageSavedToFileText(path)).show(context);
      }
    } catch (e) {
      if (context.mounted) {
        final tr = AppLocalizations.of(context);
        await showAlertDialog(
          context,
          tr.prompt,
          '${tr.errSavingImageText}: $e',
        );
      }
    }
    onSave?.call();
  }

  void _saveToGallery(BuildContext context) async {
    final picData = await _getQrImageData(context);
    if (picData == null) {
      if (context.mounted) {
        final tr = AppLocalizations.of(context);
        await showAlertDialog(
          context,
          tr.prompt,
          "${tr.errSavingImageText}: no image data found",
        );
      }
      return;
    }
    try {
      final result = await ImageGallerySaverPlus.saveImage(
        picData.buffer.asUint8List(
          picData.offsetInBytes,
          picData.lengthInBytes,
        ),
      );
      final success = result['isSuccess'] ?? false;
      if (success) {
        if (context.mounted) {
          final tr = AppLocalizations.of(context);
          SnackbarWidget.s(tr.imageSavedToGalleryText).show(context);
        }
      } else {
        throw "failed to save image to gallery";
      }
    } catch (e) {
      if (context.mounted) {
        final tr = AppLocalizations.of(context);
        await showAlertDialog(
          context,
          tr.prompt,
          '${tr.errSavingImageText}: $e',
        );
      }
    }
    onSave?.call();
  }

  Future<void> _writeToFile(ByteData data, String path) async {
    final buffer = data.buffer;
    await File(path).writeAsBytes(
        buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }
}
