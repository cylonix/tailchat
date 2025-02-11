// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import '../../gen/l10n/app_localizations.dart';
import '../../utils/utils.dart';

class Attachments extends StatelessWidget {
  final void Function()? onFileSelected;
  final void Function({bool? isVideo, bool? fromCamera})? onMediaSelected;
  const Attachments({
    super.key,
    this.onFileSelected,
    this.onMediaSelected,
  });

  Widget _attachment(IconData icon, String title, void Function() onPressed) {
    return Column(
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          iconSize: 48,
        ),
        Text(
          title,
          textScaler: TextScaler.linear(0.8),
        )
      ],
    );
  }

  Widget _container(Widget child) {
    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      alignment: Alignment.center,
      constraints: const BoxConstraints(maxWidth: 80),
      child: child,
    );
  }

  Widget _safeArea(BuildContext context, List<Widget> children) {
    final tr = AppLocalizations.of(context);
    children.add(
      _container(
        _attachment(
          Icons.arrow_back_ios_new_rounded,
          tr.cancelButton,
          () => Navigator.pop(context),
        ),
      ),
    );
    return SafeArea(
      child: SizedBox(
        height: 120,
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceAround,
          children: children,
        ),
      ),
    );
  }

  void _selectVideoOrPhoto(BuildContext context, {bool? fromCamera}) async {
    final tr = AppLocalizations.of(context);
    Navigator.pop(context);
    await showModalBottomSheet<void>(
      context: context,
      constraints: const BoxConstraints(minWidth: double.infinity),
      builder: (BuildContext context) {
        return _safeArea(context, [
          _container(
            _attachment(
              Icons.photo_outlined,
              tr.photo,
              () {
                Navigator.pop(context);
                onMediaSelected?.call(isVideo: false, fromCamera: fromCamera);
              },
            ),
          ),
          _container(
            _attachment(
              Icons.video_camera_front_outlined,
              tr.videoText,
              () {
                Navigator.pop(context);
                onMediaSelected?.call(isVideo: true, fromCamera: fromCamera);
              },
            ),
          ),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    return _safeArea(context, [
      if (isMobile())
        _container(
          _attachment(
            Icons.camera_alt_outlined,
            tr.cameraText,
            () => _selectVideoOrPhoto(context, fromCamera: true),
          ),
        ),
      _container(
        _attachment(
          Icons.photo_library_outlined,
          tr.galleryText,
          () => _selectVideoOrPhoto(context, fromCamera: false),
        ),
      ),
      _container(
        _attachment(
          Icons.file_copy_outlined,
          tr.file,
          () {
            Navigator.pop(context);
            onFileSelected?.call();
          },
        ),
      ),
    ]);
  }
}
