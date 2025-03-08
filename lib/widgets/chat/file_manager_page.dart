// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';

import 'package:file_manager/file_manager.dart';
import 'package:flutter/material.dart';
import '../base_input/button.dart';

class FileManagerPage extends StatelessWidget {
  FileManagerPage({
    super.key,
    this.allowCreateFolder = false,
    this.onFileSelected,
  });
  final bool allowCreateFolder;
  final _controller = FileManagerController();
  final void Function(File file)? onFileSelected;

  @override
  Widget build(BuildContext context) {
    return ControlBackButton(
      controller: _controller,
      child: Scaffold(
          appBar: AppBar(
            actions: [
              if (allowCreateFolder)
                IconButton(
                  onPressed: () => _createFolder(context),
                  icon: const Icon(Icons.create_new_folder_outlined),
                ),
              IconButton(
                onPressed: () => _sort(context),
                icon: const Icon(Icons.sort_rounded),
              ),
              IconButton(
                onPressed: () => _selectStorage(context),
                icon: const Icon(Icons.sd_storage_rounded),
              )
            ],
            title: ValueListenableBuilder<String>(
              valueListenable: _controller.titleNotifier,
              builder: (context, title, _) => Text(title),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                await _controller.goToParentDirectory();
              },
            ),
          ),
          body: Container(
            margin: const EdgeInsets.all(10),
            child: FileManager(
              controller: _controller,
              builder: (context, snapshot) {
                final List<FileSystemEntity> entities = snapshot;
                return ListView.builder(
                  itemCount: entities.length,
                  itemBuilder: (context, index) {
                    FileSystemEntity entity = entities[index];
                    return Card(
                      child: ListTile(
                        leading: FileManager.isFile(entity)
                            ? const Icon(Icons.feed_outlined)
                            : const Icon(Icons.folder),
                        title: Text(FileManager.basename(entity)),
                        subtitle: _subtitle(entity),
                        onTap: () async {
                          if (FileManager.isDirectory(entity)) {
                            _controller.openDirectory(entity);
                          } else {
                            onFileSelected?.call(entity as File);
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          )),
    );
  }

  Widget _subtitle(FileSystemEntity entity) {
    return FutureBuilder<FileStat>(
      future: entity.stat(),
      builder: (context, snapshot) {
        var text = "";
        if (snapshot.hasData) {
          if (entity is File) {
            int size = snapshot.data!.size;
            text = FileManager.formatBytes(size);
          } else {
            text = '${snapshot.data!.modified}'.substring(0, 10);
          }
        }
        return Text(text);
      },
    );
  }

  void _selectStorage(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: FutureBuilder<List<Directory>>(
          future: FileManager.getStorageList(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final List<FileSystemEntity> storageList = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: storageList
                        .map((e) => ListTile(
                              title: Text(FileManager.basename(e)),
                              onTap: () {
                                _controller.openDirectory(e);
                                Navigator.pop(context);
                              },
                            ))
                        .toList()),
              );
            }
            return const Dialog(
              child: CircularProgressIndicator(),
            );
          },
        ),
      ),
    );
  }

  void _sort(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                  title: const Text("Name"),
                  onTap: () {
                    _controller.sortBy(SortBy.name);
                    Navigator.pop(context);
                  }),
              ListTile(
                  title: const Text("Size"),
                  onTap: () {
                    _controller.sortBy(SortBy.size);
                    Navigator.pop(context);
                  }),
              ListTile(
                  title: const Text("Date"),
                  onTap: () {
                    _controller.sortBy(SortBy.date);
                    Navigator.pop(context);
                  }),
              ListTile(
                  title: const Text("type"),
                  onTap: () {
                    _controller.sortBy(SortBy.type);
                    Navigator.pop(context);
                  }),
            ],
          ),
        ),
      ),
    );
  }

  void _createFolder(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController folderName = TextEditingController();
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: TextField(
                    controller: folderName,
                  ),
                ),
                BaseInputButton(
                  onPressed: () async {
                    try {
                      // Create Folder
                      await FileManager.createFolder(
                        _controller.getCurrentPath,
                        folderName.text,
                      );
                      // Open Created Folder
                      _controller.setCurrentPath =
                          "${_controller.getCurrentPath}/${folderName.text}";
                    } catch (e) {
                      // ignored.
                    }
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Create Folder'),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
