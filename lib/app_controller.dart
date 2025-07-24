import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_model.dart';

class AppBindings implements Bindings {
  @override
  void dependencies() {
    Get.put(HomeController());
    Get.put(StreamController());
    Get.put(ViewController());
  }
}

class HomeController extends GetxController {
  RxString msg = 'welcome'.obs;
  RxString timeStamp = 'time'.obs;

  RxMap<String, dynamic> userSettings = <String, dynamic>{
    'settings': '', // settings.json location
    'home': '', // init location
    'target': {}, // collection of objects to operate
  }.obs;

  void setStamp() => timeStamp.value = DateTime.now().toString();

  void setMsg(String text) {
    if (msg.value != text) {
      msg.value = text;
    }
  }

  @override
  void onReady() {
    super.onReady();
    setStamp();
  }

  void showDialog(String title, String content) {
    Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Column(children: [SizedBox(width: 50), Text('OK')]),
          ),
        ],
      ),
    );
  }
}

class StreamController extends GetxController {
  final HomeController home = Get.find<HomeController>();

  String get settingsFilePath {
    return '${home.userSettings['settings']}${Platform.pathSeparator}settings.json';
  }

  @override
  void onReady() async {
    super.onReady();

    final folderPath = _localAppData();
    home.userSettings['settings'] = folderPath;
    await validateSettings(settingsFilePath);
  }

  String _localAppData() {
    String appDataPath = Platform.environment['localappdata'] ?? '';
    String appFolder = 'saveApp';
    return '$appDataPath${Platform.pathSeparator}$appFolder';
  }

  Future<void> validateSettings(String filePath) async {
    final file = File(filePath);

    try {
      if (!await file.exists()) {
        await createSettings(filePath);
        return;
      }

      final contents = await file.readAsString();

      if (contents.trim().isEmpty) {
        await createSettings(filePath);
        return;
      }

      final parsed = jsonDecode(contents);

      if (parsed is Map<String, dynamic>) {
        (home.userSettings).value = parsed;
      } else {
        throw const FormatException('corrupt settings file');
      }
    } catch (_) {
      await createSettings(filePath);
    }
  }

  Future<void> createSettings(String filePath) async {
    final file = File(filePath);
    final tempFile = File('$filePath.tmp');

    try {
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await tempFile.writeAsString(JsonEncoder.withIndent('  ').convert(home.userSettings), mode: FileMode.write);
      await tempFile.rename(filePath);
    } catch (e) {
      home.showDialog('Write Error', 'failed to write settings: $e');
    }
  }

  Future<dynamic> readSettings(String filePath, String key, [dynamic fallback]) async {
    await validateSettings(filePath);
    return home.userSettings.containsKey(key) ? home.userSettings[key] : fallback;
  }

  Future<void> updateSettings(String filePath, String key, dynamic value) async {
    await validateSettings(filePath);
    home.userSettings[key] = value;
    await createSettings(filePath);
  }

  Future<void> deleteSettings(String filePath, String key) async {
    await validateSettings(filePath);
    home.userSettings.remove(key);
    await createSettings(filePath);
  }
}



class ViewController extends GetxController {
  final HomeController home = Get.find<HomeController>();

  String viewLocation = '';
  RxList<FileObject> viewContents = <FileObject>[].obs;
  final String defaultLocation = Directory.current.path;

  @override
  void onReady() {
    super.onReady();

    // try to load from user settings if available
    final savedLocation = home.userSettings['home'];
    viewLocation = (savedLocation is String && savedLocation.isNotEmpty) ? savedLocation : defaultLocation;

    readLocation();
  }

  // loads the content of viewLocation into viewContents
  Future<void> readLocation() async {
    final dir = Directory(
      viewLocation.endsWith(Platform.pathSeparator) ? viewLocation : '$viewLocation${Platform.pathSeparator}',
    );

    if (!await dir.exists()) {
      home.showDialog('Error', 'directory does not exist:\n$viewLocation');
      return;
    }

    final Map<String, FileObject> previousMap = {for (final item in viewContents) item.identitySignature: item};

    List<FileObject> tempContents = [];

    await for (final entry in dir.list()) {
      try {
        final stat = await entry.stat();
        final name = entry.path.split(Platform.pathSeparator).last;
        final created = stat.changed;
        final modified = stat.modified;
        final identity = '${entry.path}|$created';

        FileObject? oldItem = previousMap[identity];

        if (entry is File) {
          tempContents.add(
            FileItem(
              name: name,
              path: entry.path,
              created: created,
              modified: modified,
              size: stat.size,
              extension: name.contains('.') ? name.split('.').last : '',
            )..isSelected.value = oldItem?.isSelected.value ?? false,
          );
        } else if (entry is Directory) {
          int itemCount = 0;
          try {
            itemCount = await entry.list().length;
          } catch (_) {}

          tempContents.add(
            FolderItem(name: name, path: entry.path, created: created, modified: modified, itemCount: itemCount)
              ..isSelected.value = oldItem?.isSelected.value ?? false,
          );
        }
      } catch (_) {}
    }

    // Always apply sorting before pushing to the UI
    tempContents.sort((a, b) {
      final aIsFolder = a is FolderItem ? 0 : 1;
      final bIsFolder = b is FolderItem ? 0 : 1;
      final typeCompare = aIsFolder.compareTo(bIsFolder);
      return typeCompare != 0 ? typeCompare : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    viewContents.value = tempContents;
  }

  /// sorts viewContents alphabetically by name
  void sortNameAsc() {
    viewContents.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  // sorts viewContents with folders first, then files
  void sortFolderFirst() {
    viewContents.sort((a, b) {
      final aIsFolder = a is FolderItem ? 0 : 1;
      final bIsFolder = b is FolderItem ? 0 : 1;
      final typeCompare = aIsFolder.compareTo(bIsFolder);

      if (typeCompare != 0) return typeCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

}

