import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_model.dart';

class HomeController extends GetxController {
  RxString msg = 'welcome'.obs;
  RxString timeStamp = 'time'.obs;

  void setStamp() => timeStamp.value = DateTime.now().toString();

  void setMsg(String text) {
    if (msg.value != text) {
      msg.value = text;
    }
  }

  @override
  void onInit() {
    super.onInit();
    setStamp();
  }
}

class VersioningController extends GetxController {
  RxList<FileObject> folderContents = <FileObject>[].obs;
  Map<String, dynamic> userSettings = {};

  

  RxString userSelection = ''.obs;

  final Map<String, dynamic> defaultSettings = {
    'settingsAddress': '',
    'targetAddress': '',
  };

  VersioningController() {
    defaultSettings['settingsAddress'] = _localAppDataAddress();
    defaultSettings['targetAddress'] = Directory.current.path;
  }

  @override
  void onReady() async {
    super.onReady();
    await validateSettings(defaultSettings['settingsAddress']);
  }

  void _showDialog(String title, String content) {
    Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('OK')),
        ],
      ),
    );
  }

  String _settingsAddress(String folderPath) {
    return '${folderPath.endsWith(Platform.pathSeparator) ? folderPath : '$folderPath${Platform.pathSeparator}'}settings.json';
  }

  String _localAppDataAddress() {
    String appDataPath = Platform.environment['localappdata'] ?? '';
    String appFolder = 'saveApp';
    return '$appDataPath${Platform.pathSeparator}$appFolder';
  }

  // ensures that settings.json exists and is valid
  Future<void> validateSettings(String basePath) async {
    final file = File(_settingsAddress(basePath));

    try {
      if (!await file.exists()) {
        // file does not exist, create it with default settings
        userSettings = Map.from(defaultSettings);
        await writeSettings(basePath);
        return;
      }

      final contents = await file.readAsString();

      if (contents.trim().isEmpty) {
        // file is empty, write default settings
        userSettings = Map.from(defaultSettings);
        await writeSettings(basePath);
        return;
      }

      // attempt to parse the JSON
      final parsed = jsonDecode(contents);

      if (parsed is Map<String, dynamic>) {
        // load settings directly from the file without merging
        userSettings = parsed;
      } else {
        throw const FormatException('corrupt settings file');
      }
    } catch (_) {
      // on error, revert to default settings
      userSettings = Map.from(defaultSettings);
      await writeSettings(basePath);
    }
  }

  Future<void> writeSettings(String basePath) async {
    final filePath = _settingsAddress(basePath);
    final file = File(filePath);
    final tempFile = File('$filePath.tmp');

    try {
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      await tempFile.writeAsString(
        JsonEncoder.withIndent('  ').convert(userSettings),
        mode: FileMode.write,
      );

      await tempFile.rename(filePath);
    } catch (e) {
      _showDialog('Write Error', 'failed to write settings: $e');
    }
  }

  Future<void> updateSetting(String basePath, String key, dynamic value) async {
    await validateSettings(basePath);
    userSettings[key] = value;
    await writeSettings(basePath);
  }

  Future<void> removeSetting(String basePath, String key) async {
    await validateSettings(basePath);
    userSettings.remove(key);
    await writeSettings(basePath);
  }

  Future<dynamic> getSetting(
    String basePath,
    String key, [
    dynamic fallback,
  ]) async {
    await validateSettings(basePath);
    return userSettings.containsKey(key) ? userSettings[key] : fallback;
  }

  Future<void> loadTarget(String path) async {
    try {
      final dir = Directory(
        path.endsWith(Platform.pathSeparator)
            ? path
            : '$path${Platform.pathSeparator}',
      );

      if (!await dir.exists()) {
        throw Exception('directory does not exist: $path');
      }

      final entries = dir.list();
      List<FileObject> tempContents = [];

      await for (var entry in entries) {
        final stat = await entry.stat();
        final name = entry.path.split(Platform.pathSeparator).last;
        final created = stat.changed;
        final modified = stat.modified;

        if (entry is File) {
          tempContents.add(
            FileItem(
              name: name,
              path: entry.path,
              created: created,
              modified: modified,
              size: stat.size,
              extension: name.contains('.') ? name.split('.').last : '',
            ),
          );
        } else if (entry is Directory) {
          final itemCount = await entry.list().length;
          tempContents.add(
            FolderItem(
              name: name,
              path: entry.path,
              created: created,
              modified: modified,
              itemCount: itemCount,
            ),
          );
        }
      }

      // folders first, then alphabetical
      tempContents.sort((a, b) {
        final aIsDir = a is FolderItem;
        final bIsDir = b is FolderItem;
        return aIsDir != bIsDir
            ? (aIsDir ? -1 : 1)
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      folderContents
        ..clear()
        ..addAll(tempContents);
    } catch (e) {
      _showDialog('Error', 'failed to read target: $e');
    }
  }

}

class AppBindings implements Bindings {
  @override
  void dependencies() {
    Get.put(HomeController());
    Get.put(VersioningController());
  }
}