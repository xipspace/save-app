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
    // home is now dependant of snapshot
    'home': '', // init location
    'selection': {}, // collection of objects to operate
  }.obs;

  RxMap<String, Snapshot> snapshots = <String, Snapshot>{}.obs;

  void createSnapshot(String homePath, List<FileObject> selectedItems, {String? title, String? customName, String? customStorage}) {
    final id = generateTimestamp();
    final snapshotTitle = title ?? '${id}_snapshot';

    final snapshot = Snapshot(id: id, title: snapshotTitle, name: customName, storage: customStorage, home: homePath, items: selectedItems);

    snapshots[id] = snapshot;
  }

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

  void showEdit(Snapshot snapshot) {
    final originalId = snapshot.id;
    Get.dialog(
      AlertDialog(
        title: Text('edit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'title'),
              onChanged: (value) => snapshot.title = value,
              controller: TextEditingController(text: snapshot.title),
            ),
            TextField(
              decoration: InputDecoration(labelText: 'name'),
              onChanged: (value) => snapshot.name = value,
              controller: TextEditingController(text: snapshot.name),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
            },
            child: const Column(children: [SizedBox(width: 50), Text('cancel')]),
          ),
          TextButton(
            onPressed: () {
              snapshots[originalId] = snapshot;
              snapshots.refresh();
              Get.back();
            },
            child: const Column(children: [SizedBox(width: 50), Text('OK')]),
          ),
        ],
      ),
    );
  }

}

class ViewController extends GetxController {
  final home = Get.find<HomeController>();
  final stream = Get.find<StreamController>();

  
  String viewLocation = '';
  RxString currentDisk = ''.obs;
  RxList<FileObject> viewContents = <FileObject>[].obs;
  final String defaultLocation = Directory.current.path;

  RxList<String> availableDisks = <String>[].obs;

  Future<void> initView() async {
    final savedLocation = home.userSettings['home'];
    viewLocation = (savedLocation is String && savedLocation.isNotEmpty) ? savedLocation : defaultLocation;
    currentDisk.value = viewLocation.substring(0, 3);

    await loadDisks();
    await readLocation();
  }

  // get disks for Windows
  Future<List<String>> getAvailableDisks() async {
    if (!Platform.isWindows) return [];
    List<String> disks = [];
    for (var letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
      final path = '$letter:\\';
      if (await Directory(path).exists()) {
        disks.add(path);
      }
    }
    return disks;
  }

  // populate availableDisks
  Future<void> loadDisks() async {
    availableDisks.value = await getAvailableDisks();
  }

  // change disk and load its contents
  void changeDisk(String diskPath) async {
    viewLocation = diskPath;
    currentDisk.value = diskPath.substring(0, 3);
    await readLocation();
  }

  

  Future<void> readLocation() async {
    // load the location from userSettings.home or from the default location as indicated at onReady
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
    final selected = viewContents.where((item) => item.isSelected.value && item.name != '..').toList();

    if (selected.isEmpty) {
      home.showDialog('Target', 'Select at least one file or folder');
      return;
    }

    // update in memory
    home.userSettings['selection'] = selected.map((e) => e.toJson()).toList();
    home.userSettings['home'] = viewLocation;

    // persist to settings.json
    await stream.updateJsonKey(stream.settingsFilePath, home.userSettings, 'home', viewLocation);
    await stream.updateJsonKey(stream.settingsFilePath, home.userSettings, 'selection', selected.map((e) => e.toJson()).toList());

    // create typed snapshot
    home.createSnapshot(viewLocation, selected);

    home.showDialog('Target', 'Saved ${selected.length} items');
  }
}

class StreamController extends GetxController {
  final home = Get.find<HomeController>();

  // define file paths
  String get settingsFilePath => '${home.userSettings['settings']}${Platform.pathSeparator}settings.json';
  String get snapshotsFilePath => '${home.userSettings['settings']}${Platform.pathSeparator}snapshots.json';

  @override
  void onReady() async {
    super.onReady();

    final folderPath = _localAppData();
    home.userSettings['settings'] = folderPath;

    // load data
    await validateJsonFile(settingsFilePath, home.userSettings);
    await validateJsonFile(snapshotsFilePath, home.snapshots);

    // auto-save snapshots
    ever(home.snapshots, (_) => saveSnapshots());
  }

  Future<void> saveSnapshots() async {
    await createJsonFile(snapshotsFilePath, home.snapshots.map((key, value) => MapEntry(key, value.toJson())));
  }

  String _localAppData() {
    String appDataPath = Platform.environment['localappdata'] ?? '';
    String appFolder = 'saveApp';
    return '$appDataPath${Platform.pathSeparator}$appFolder';
  }

  Future<void> validateJsonFile(String filePath, dynamic target) async {
    final file = File(filePath);
    try {
      if (!await file.exists()) {
        await createJsonFile(filePath, target);
        return;
      }

      final contents = await file.readAsString();
      if (contents.trim().isEmpty) {
        await createJsonFile(filePath, target);
        return;
      }

      final parsed = jsonDecode(contents);

      if (target is RxMap<String, Snapshot> && parsed is Map<String, dynamic>) {
        target.clear();
        parsed.forEach((key, value) {
          try {
            target[key] = Snapshot.fromJson(value);
          } catch (e) {
            home.showDialog('Error', 'Failed to parse snapshot $key: $e');
          }
        });
      } else if (target is RxMap && parsed is Map<String, dynamic>) {
        target.clear();
        target.addAll(parsed);
      } else {
        throw const FormatException('Invalid JSON file format.');
      }
    } catch (e) {
      home.showDialog('Error', 'Exception caught during validation of $filePath: $e');
      if (!await file.exists() || (await file.readAsString()).trim().isEmpty) {
        await createJsonFile(filePath, target);
      } else {
        home.showDialog('Error', 'Failed to parse existing file, using it as is.');
      }
    }
  }

  Future<void> createJsonFile(String filePath, dynamic data) async {
    final file = File(filePath);
    final tempFile = File('$filePath.tmp');

    try {
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      dynamic serializable = data;
      if (data is RxMap<String, Snapshot>) {
        serializable = {for (var entry in data.entries) entry.key: entry.value.toJson()};
      }

      await tempFile.writeAsString(JsonEncoder.withIndent('  ').convert(serializable), mode: FileMode.write);
      await tempFile.rename(filePath);
    } catch (e) {
      home.showDialog('Write Error', 'failed to write file: $e');
    }
  }

  Future<dynamic> readJsonKey(String filePath, Map<String, dynamic> targetMap, String key, [dynamic fallback]) async {
    await validateJsonFile(filePath, targetMap);
    return targetMap.containsKey(key) ? targetMap[key] : fallback;
  }

  Future<void> updateJsonKey(String filePath, Map<String, dynamic> targetMap, String key, dynamic value) async {
    await validateJsonFile(filePath, targetMap);
    targetMap[key] = value;
    await createJsonFile(filePath, targetMap);
  }

  Future<void> deleteJsonKey(String filePath, Map<String, dynamic> targetMap, String key) async {
    await validateJsonFile(filePath, targetMap);
    targetMap.remove(key);
    await createJsonFile(filePath, targetMap);
  }
}


class ArchiveController extends GetxController {
  final home = Get.find<HomeController>();
  final view = Get.find<ViewController>();

  // list all .zip containers in a folder
  Future<List<File>> listContainers(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return [];
    return dir.listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.zip')).toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  }

  Future<void> compressTarget(Snapshot snapshot) async {
    final List targets = snapshot.items.map((e) => e.toJson()).toList();
    final String storagePath = snapshot.storage;

    if (targets.isEmpty || storagePath.isEmpty) {
      home.showDialog('Error', 'No valid target or storage path.');
      return;
    }

    final archive = Archive();
    int fileCount = 0;
    int folderCount = 0;
    int totalBytes = 0;

    try {
      for (var item in targets) {
        final type = item['type'];
        final path = item['path'];

        final entity = FileSystemEntity.typeSync(path);
        if (entity == FileSystemEntityType.notFound) continue;

        final basePath = Directory(snapshot.home).path;
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

      // file name to use a timestamp otherwise it will overwrite
      // final zipName = '${snapshot.id}_${snapshot.name}.zip';
      final zipName = '${home.generateTimestamp()}_${snapshot.name}.zip';
      final zipPath = '$storagePath${Platform.pathSeparator}$zipName';

      final zipBytes = ZipEncoder().encode(archive);
      await File(zipPath).writeAsBytes(zipBytes);

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

  // extract target container or fallback to latest from storage
  Future<void> extractTarget(Snapshot snapshot, {File? container}) async {
    try {
      // decide which container to extract
      File? targetZip = container;

      if (targetZip == null) {
        // fallback: load from snapshot.storage
        if (snapshot.storage.isEmpty) {
          home.showDialog('Error', 'No storage path defined in snapshot.');
          return;
        }

        final containers = await listContainers(snapshot.storage);
        if (containers.isEmpty) {
          home.showDialog('Error', 'No container found in:\n${snapshot.storage}');
          return;
        }

        targetZip = containers.first; // pick latest
      }

      final zipName = targetZip.path.split(Platform.pathSeparator).last;

      // ask for confirmation before restoring
      Get.dialog(
        AlertDialog(
          title: const Text('Confirm Restore'),
          content: Text(
            'Do you want to extract:\n$zipName\n\n'
            'From: ${snapshot.storage}\n'
            'Into: ${snapshot.home}',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(), // cancel
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Get.back(); // close dialog before extraction

                try {
                  final bytes = await targetZip!.readAsBytes();
                  final archive = ZipDecoder().decodeBytes(bytes);

                  int fileCount = 0;
                  int folderCount = 0;
                  int totalBytes = 0;

                  // extract each file/folder into snapshot.home
                  for (final file in archive) {
                    final outPath = '${snapshot.home}${Platform.pathSeparator}${file.name}';

                    if (file.isFile) {
                      final outFile = File(outPath);
                      await outFile.parent.create(recursive: true);
                      await outFile.writeAsBytes(file.content as List<int>);
                      fileCount++;
                      totalBytes += file.size;
                    } else {
                      await Directory(outPath).create(recursive: true);
                      folderCount++;
                    }
                  }

                  // show summary after extraction
                  home.showDialog(
                    'Extraction Complete',
                    'Extracted: $zipName\n'
                        'Files: $fileCount\n'
                        'Folders: $folderCount\n'
                        'Total Size: ${totalBytes ~/ 1024} KB',
                  );
                } catch (e) {
                  home.showDialog('Error', 'Extraction failed: $e');
                }
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      home.showDialog('Error', 'Extraction failed: $e');
    }
  }

}
