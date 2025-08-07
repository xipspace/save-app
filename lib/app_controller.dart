import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:archive/archive.dart';

import 'app_model.dart';

class AppBindings implements Bindings {
  @override
  void dependencies() {
    Get.put(HomeController());
    Get.put(StreamController());
    Get.put(ViewController());
    Get.put(ArchiveController());
  }
}

class HomeController extends GetxController {
  RxString msg = 'welcome'.obs;
  RxString timeStamp = 'time'.obs;

  RxMap<String, dynamic> userSettings = <String, dynamic>{
    'settings': '', // settings.json location
    'home': '', // init location
    'selection': {}, // collection of objects to operate
  }.obs;

  RxMap<String, dynamic> userTree = <String, dynamic>{}.obs;

  void setStamp() => timeStamp.value = DateTime.now().toString();

  void setMsg(String text) {
    if (msg.value != text) {
      msg.value = text;
    }
  }

  String generateTimestamp() {
    final now = DateTime.now();
    final date = '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final time = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final millis = now.millisecond.toString().padLeft(3, '0');
    return '${date}_$time$millis';
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



class ViewController extends GetxController {
  final HomeController home = Get.find<HomeController>();
  final StreamController stream = Get.find<StreamController>();

  String viewLocation = '';
  RxList<FileObject> viewContents = <FileObject>[].obs;
  final String defaultLocation = Directory.current.path;

  @override
  void onReady() {
    super.onReady();
    final savedLocation = home.userSettings['home'];
    viewLocation = (savedLocation is String && savedLocation.isNotEmpty) ? savedLocation : defaultLocation;
    readLocation();
  }

  Future<void> readLocation() async {
    // read location should load the location from userSettings.home or from the default location as indicated at onReady
    // it should populate viewContents with items from the model
    // use model flags for content filtering
    final dir = Directory(viewLocation.endsWith(Platform.pathSeparator) ? viewLocation : '$viewLocation${Platform.pathSeparator}');

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

    tempContents.sort((a, b) {
      final aIsFolder = a is FolderItem ? 0 : 1;
      final bIsFolder = b is FolderItem ? 0 : 1;
      final typeCompare = aIsFolder.compareTo(bIsFolder);
      return typeCompare != 0 ? typeCompare : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    // add ".." if not root
    final parent = Directory(viewLocation).parent.path;
    final isRoot = Directory(viewLocation).path == parent;

    if (!isRoot) {
      tempContents.insert(
        0,
        FolderItem(
          name: '..',
          path: parent,
          created: DateTime.fromMillisecondsSinceEpoch(0),
          modified: DateTime.fromMillisecondsSinceEpoch(0),
          itemCount: 0,
        )..isSelected.value = false,
      );
    }

    viewContents.value = tempContents;


  }

  void sortNameAsc() {
    viewContents.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> saveSelectedItems() async {
    // Get the currently selected items
    final selected = viewContents
        .where((item) => item.isSelected.value && item.name != '..')
        .map(
          (item) => {
            'type': item is FolderItem ? 'folder' : 'file',
            'name': item.name,
            'path': item.path,
            'created': item.created.toIso8601String(), // Convert to string
            'modified': item.modified.toIso8601String(), // Convert to string
          },
        )
        .toList();

    if (selected.isEmpty) {
      home.showDialog('Target', 'Select at least one file or folder');
      return;
    }

    // Clear previous selections and set new selections
    home.userSettings['selection'] = selected;

    // Update the user tree with a new timestamp key
    final timestampKey = 'game_snapshot_${home.generateTimestamp()}';
    home.userTree[timestampKey] = selected;

    // Update settings in the stream
    home.userSettings['home'] = viewLocation;
    await stream.updateSettings(stream.settingsFilePath, 'home', viewLocation);
    await stream.updateSettings(stream.settingsFilePath, 'selection', selected);

    home.showDialog('Target', 'Saved ${selected.length} items');
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
        home.userSettings.clear();
        home.userSettings.addAll(parsed);
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



class ArchiveController extends GetxController {
  final HomeController home = Get.find<HomeController>();
  final ViewController view = Get.find<ViewController>();

  // use saved target at usersettings

  Future<void> compressTarget() async {
    final List targets = home.userSettings['target'] ?? [];
    final String homePath = home.userSettings['home'] ?? '';

    if (targets.isEmpty || homePath.isEmpty) {
      home.showDialog('Error', 'No valid target or home path.');
      return;
    }

    final archive = Archive();
    int fileCount = 0;
    int folderCount = 0;
    int totalBytes = 0;

    try {
      for (var item in targets) {
        final type = item['type'];
        // final name = item['name'];
        final path = item['path'];

        final entity = FileSystemEntity.typeSync(path);
        if (entity == FileSystemEntityType.notFound) continue;

        final basePath = Directory(homePath).path;
        final relativePath = path.replaceFirst('$basePath${Platform.pathSeparator}', '');

        if (type == 'file' && File(path).existsSync()) {
          final file = File(path);
          final bytes = await file.readAsBytes();
          archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
          fileCount++;
          totalBytes += bytes.length;
        } else if (type == 'folder' && Directory(path).existsSync()) {
          final dir = Directory(path);
          archive.addFile(ArchiveFile('$relativePath/', 0, []));
          folderCount++;

          await for (final entity in dir.list(recursive: true)) {
            final subRelativePath = entity.path.replaceFirst('$basePath${Platform.pathSeparator}', '');

            if (entity is File) {
              final bytes = await entity.readAsBytes();
              archive.addFile(ArchiveFile(subRelativePath, bytes.length, bytes));
              fileCount++;
              totalBytes += bytes.length;
            } else if (entity is Directory) {
              archive.addFile(ArchiveFile('$subRelativePath/', 0, []));
              folderCount++;
            }
          }
        }
      }

      final timestamp = home.generateTimestamp();
      final zipName = 'archive_$timestamp.zip';
      final zipPath = '$homePath${Platform.pathSeparator}$zipName';

      final zipBytes = ZipEncoder().encode(archive);
      await File(zipPath).writeAsBytes(zipBytes);

      if (homePath == view.viewLocation) {
        await view.readLocation();
      }

      home.showDialog(
        'Compression Complete',
        'Created: $zipName\n'
            'Files: $fileCount\n'
            'Folders: $folderCount\n'
            'Total Size: ${totalBytes ~/ 1024} KB',
      );
    } catch (e) {
      home.showDialog('Error', 'Compression failed: $e');
    }

  }

  Future<void> extractTarget() async {
    
    // 
    
  }
}