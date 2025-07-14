import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
  RxList<String> folderContents = <String>[].obs;
  Map<String, dynamic> userSettings = {};

  final Map<String, dynamic> defaultSettings = {
    'settingsAddress': 'S:\\',
    'targetAddress': 'S:\\',
  };

  @override
  void onReady() async {
    super.onReady();

    const initialPath = 'S:\\'; // fallback location to load/create settings.json
    await validateSettings(initialPath);
  }

  void _showErrorDialog(String title, String content) {
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

  // ensures that settings.json exists and is valid
  Future<void> validateSettings(String basePath) async {
    final file = File(_settingsAddress(basePath));

    try {
      if (!await file.exists()) {
        userSettings = Map.from(defaultSettings);
        await writeSettings(basePath);
        return;
      }

      final contents = await file.readAsString();

      if (contents.trim().isEmpty) {
        userSettings = Map.from(defaultSettings);
        await writeSettings(basePath);
        return;
      }

      final parsed = jsonDecode(contents);

      if (parsed is Map<String, dynamic>) {
        // Merge loaded settings with defaults (loaded keys overwrite defaults)
        userSettings = {...defaultSettings, ...parsed};

        // Write back merged settings to ensure all keys saved
        await writeSettings(basePath);
      } else {
        throw const FormatException('corrupt settings file');
      }
    } catch (_) {
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
      _showErrorDialog('Write Error', 'failed to write settings: $e');
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
        path.endsWith('/') ? path.substring(0, path.length - 1) : path,
      );
      if (!await dir.exists()) {
        throw Exception('directory does not exist: $path');
      }

      final entries = dir.list();
      List<String> tempContents = [];

      await for (var entry in entries) {
        final name =
            entry.path
                .split(Platform.pathSeparator)
                .where((e) => e.isNotEmpty)
                .last;
        if (entry is File) {
          tempContents.add(name);
        } else if (entry is Directory) {
          tempContents.add('/$name');
        }
      }

      tempContents.sort((a, b) {
        bool aIsDir = a.startsWith('/');
        bool bIsDir = b.startsWith('/');
        return aIsDir != bIsDir
            ? (aIsDir ? -1 : 1)
            : a.toLowerCase().compareTo(b.toLowerCase());
      });

      folderContents
        ..clear()
        ..addAll(tempContents);
    } catch (e) {
      _showErrorDialog('Error', 'failed to read target: $e');
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