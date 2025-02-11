// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:provider/provider.dart';

import '../api/config.dart';
import '../gen/l10n/app_localizations.dart';
import '../models/chat/chat_message.dart';
import '../models/chat/chat_session.dart';
import '../models/media_preview_item.dart';
import '../models/new_session_notifier.dart';
import '../models/session.dart';
import '../models/contacts/user_profile.dart';
import '../utils/global.dart';
import '../utils/utils.dart' as utils;
import 'base_input/button.dart';
import 'main_app_bar.dart';
import 'main_bottom_bar.dart';
import 'snackbar_widget.dart';

/// ShareMediaPreviewScreen shares the media to a chat session.
class SharingMediaPreviewScreen extends StatefulWidget {
  final ChatSession session;
  final List<String>? paths;
  final List<types.Message>? messages;
  final String? text;
  final bool showSideBySide;
  const SharingMediaPreviewScreen({
    super.key,
    required this.session,
    this.paths,
    this.messages,
    this.text,
    this.showSideBySide = false,
  });
  @override
  State<SharingMediaPreviewScreen> createState() =>
      _SharingMediaPreviewScreenState();
}

class _SharingMediaPreviewScreenState extends State<SharingMediaPreviewScreen> {
  final _pageController = PageController(
    initialPage: 0,
    viewportFraction: 0.95,
    keepPage: false,
  );
  final _galleryItems = <MediaPreviewItem>[];
  final _scaffoldKey = GlobalKey();
  final _textController = TextEditingController();
  int _galleryIndex = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      final paths = widget.paths;
      if (paths == null) {
        return;
      }
      setState(() {
        var i = 0;
        for (var path in paths) {
          final decoded = Uri.decodeFull(path);
          _galleryItems.add(
            MediaPreviewItem(
              id: i,
              path: decoded,
              resource: File(decoded),
              controller: TextEditingController(),
              isSelected: i == 0,
            ),
          );
          i++;
        }
      });
    });
  }

  @override
  void dispose() {
    for (var e in _galleryItems) {
      e.controller?.dispose();
    }
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final title = tr.sendToText + widget.session.titleSync;
    return Scaffold(
      key: _scaffoldKey,
      appBar: MainAppBar(title: title),
      body: Center(child: _body),
    );
  }

  Widget get _body {
    final hasPreview = _galleryItems.isNotEmpty;
    final hasText = widget.text != null;
    final hasMessages = widget.messages?.isNotEmpty ?? false;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          const SizedBox(height: 5),
          if (hasPreview) _fullMediaPreview(),
          if (hasPreview) _fileName(),
          if (hasText) _sharedTextView(),
          if (hasPreview || hasText) _addCaptionPreview(hasPreview, hasText),
          if (hasPreview) _horizontalMediaFilesView(),
          if (hasMessages) _forwardMessagesView(),
        ],
      ),
    );
  }

  Widget _fullMediaPreview() {
    const filePng = "packages/sase_app_ui/assets/images/ic_file.png";
    return Expanded(
      child: PageView(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        onPageChanged: _mediaPreviewChanged,
        children: _galleryItems.map((e) {
          final suffix = e.path.split('.').last.toLowerCase();
          final isImage = utils.imageExtensions.contains(suffix);
          final file = File(e.path);
          return isImage ? Image.file(file) : Image.asset(filePng);
        }).toList(),
      ),
    );
  }

  void _mediaPreviewChanged(int value) {
    _galleryIndex = value;
    setState(() {
      for (var element in _galleryItems) {
        element.isSelected = (element.id == value);
      }
    });
  }

  Widget _fileName() {
    final name = _galleryItems[_galleryIndex].path.split('/').last;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(name),
    );
  }

  Widget _addCaptionPreview(bool hasPreview, bool hasText) {
    final tr = AppLocalizations.of(context);
    const sendPng = "packages/sase_app_ui/assets/images/ic_send.png";
    final controller = _galleryItems.isNotEmpty
        ? _galleryItems[_galleryIndex].controller
        : _textController;
    Widget captionTextField = TextFormField(
      controller: controller,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        hintText: tr.addCaption,
        filled: true,
        counter: const Offstage(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 5),
        border: InputBorder.none,
      ),
      onFieldSubmitted: (value) {},
      keyboardType: TextInputType.text,
      onTap: () {},
    );
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 20, top: 10),
            child: captionTextField,
          ),
        ),
        GestureDetector(
          onTap: () {
            for (var element in _galleryItems) {
              element.caption = element.controller?.text;
            }
            if (hasPreview) {
              _onSharingTap(_sendFiles);
            }
            if (hasText) {
              _onSharingTap(_sendText);
            }
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Image.asset(sendPng, scale: 2.7),
          ),
        ),
      ],
    );
  }

  Widget _horizontalMediaFilesView() {
    const filePng = "packages/sase_app_ui/assets/images/ic_file.png";
    Widget horizontalMediaW = Container(
      height: 60,
      margin: const EdgeInsets.only(left: 15, bottom: 10, top: 5),
      child: ListView.separated(
        itemCount: _galleryItems.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = _galleryItems[index];
          final ext = item.path.split('.').last.toLowerCase();
          final isImage = utils.imageExtensions.contains(ext);
          final file = File(item.path);
          final img = isImage ? Image.file(file) : Image.asset(filePng);
          return GestureDetector(
            onTap: () => _onTapHorizontalMedia(index),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: item.isSelected ? Colors.grey : Colors.white,
                  width: 1.0,
                ),
              ),
              child: img,
            ),
          );
        },
        scrollDirection: Axis.horizontal,
      ),
    );
    return (MediaQuery.of(context).viewInsets.bottom == 0)
        ? horizontalMediaW
        : const SizedBox();
  }

  void _onTapHorizontalMedia(int index) {
    setState(() {
      for (var element in _galleryItems) {
        element.isSelected = (element.id == index);
      }
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeIn,
    );
  }

  Widget _sharedTextView() {
    final tr = AppLocalizations.of(context);
    var text = widget.text ?? "";
    if (text.length > 500) {
      text = '${text.substring(0, 500)} ...';
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(tr.sharedTextText),
        const SizedBox(height: 10),
        Text(text),
      ],
    );
  }

  Widget _forwardMessagesView() {
    final tr = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.headlineSmall;
    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      padding: const EdgeInsets.all(20),
      child: ListView(
        shrinkWrap: true,
        children: [
          const SizedBox(height: 15),
          ListTile(
            title: Text(
              "${tr.forwardMessagesToText} ${widget.session.titleSync}",
              textAlign: TextAlign.center,
              style: style,
            ),
            subtitle: Text(
              widget.messages?[0].summary ?? "",
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 15),
          BaseInputButton(
            child: Text(tr.cancelButton),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 15),
          BaseInputButton(
            child: Text(tr.confirmText),
            onPressed: () => _onSharingTap(_sendMessages),
          ),
        ],
      ),
    );
  }

  Future<void> _onSharingTap(void Function(String, UserProfile) onSend) async {
    final selfUser = Pst.selfUser;
    final selfDevice = Pst.selfDevice;
    final chatID = widget.session.sessionID;
    final tr = AppLocalizations.of(context);
    if (selfUser == null || selfDevice == null) {
      SnackbarWidget.e(tr.selfUserNotFoundError).show(context);
      return;
    }

    // Open or switch to the chat page.
    _showChatPage(widget.session);
    onSend(chatID, selfUser);
  }

  void _showChatPage(ChatSession session) {
    final notifier = context.read<NewSessionNotifier>();
    notifier.add(session);
    bool pushNewChatPage = true;
    Navigator.of(context).popUntil((route) {
      final currentName = route.settings.name;
      Global.logger.d("current name is $currentName");
      if (currentName == '/chat/${session.sessionID}') {
        pushNewChatPage = false;
        return true;
      }
      if (currentName == '/') {
        return true;
      }
      // Continue popping
      return false;
    });

    if (widget.showSideBySide) {
      session.status = SessionStatus.unread;
      final notifier = context.read<BottomBarSelection>();
      notifier.select(MainBottomBar.pageIndexOf(MainBottomBarPage.sessions));
    } else if (pushNewChatPage) {
      session.status = SessionStatus.read;
      Navigator.of(context).pushNamed(
        '/chat/${session.sessionID}',
        arguments: session.toJson(),
      );
    } else {
      Global.logger.d("skip showing the new chat page");
    }
  }

  void _sendMessages(String chatID, UserProfile selfUser) async {
    final messages = widget.messages;
    if (messages == null) {
      return;
    }
    for (var message in messages) {
      final chatMessage = ChatMessage.copyFrom(chatID, message, up: selfUser);
      await chatMessage.save();
      chatMessage.notify();
    }
  }

  void _sendFiles(String chatID, UserProfile selfUser) async {
    final paths = widget.paths;
    if (paths == null) {
      return;
    }
    Future.forEach(_galleryItems, (item) async {
      final path = item.path;
      final file = File(path);
      final size = await file.length();
      final suffix = path.split('.').last.toLowerCase();
      final isImage = utils.imageExtensions.contains(suffix);
      ui.Image? image;
      if (isImage) {
        final bytes = await file.readAsBytes();
        image = await decodeImageFromList(bytes);
      }
      final message = ChatMessage.fromFile(
        chatID,
        path,
        size,
        up: selfUser,
        image: image,
        caption: item.caption,
      );
      // Need to save it here to avoid race conditions on chat page not yet
      // ready to receive notifications.
      await message.save();
      await message.copyFile(path);
      message.notify();
    });
  }

  void _sendText(String chatID, UserProfile selfUser) async {
    final text = widget.text;
    final caption = _textController.text.isEmpty ? null : _textController.text;
    if (text == null) {
      return;
    }
    final message = ChatMessage.fromText(
      chatID,
      text,
      up: selfUser,
      caption: caption,
    );
    // Need to save it here to avoid race conditions on chat page not yet
    // ready to receive notifications.
    await message.save();
    message.notify();
  }
}
