import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_controller.dart';
import 'app_model.dart';

enum ActionType { save, compress }

void main() => runApp(const MainApp());

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'saveApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        textTheme: const TextTheme(
          titleSmall: TextStyle(fontSize: 16),
          bodySmall: TextStyle(fontSize: 14),
          labelSmall: TextStyle(fontSize: 12),
        ),
      ),
      initialRoute: '/',
      initialBinding: AppBindings(),
      home: const SafeArea(child: HomeScreen()),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final viewController = Get.find<ViewController>();
    final versioningController = Get.find<VersioningController>();
    final archiveController = Get.find<ArchiveController>();

    final Map<ActionType, VoidCallback> actionMap = {
      ActionType.save: () async {
        final currentFolder = versioningController.currentPath;
        await versioningController.updateSetting(
          versioningController.userSettings['settingsAddress'],
          'targetAddress',
          currentFolder,
        );
        viewController.showDialog('Target', 'Current target: $currentFolder');
      },
      ActionType.compress: () async {
        await archiveController.compressTargetDirectory();
      },
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('@saveApp'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(icon: const Icon(Icons.dark_mode_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Obx(() => Text(controller.msg.value)),
                Obx(() => Text(controller.timeStamp.value)),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children:
                      ActionType.values.map((action) {
                        final label = action.name.capitalizeFirst ?? action.name;

                        return SizedBox(
                          width: 150,
                          child: Card(
                            elevation: 2,
                            child: InkWell(
                              onTap: actionMap[action],
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 20,
                                ),
                                child: Center(
                                  child: Text(
                                    label,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 20),
                // Obx(() => Text(versioningController.folderContents.toString())),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  elevation: 2,
                  child: Obx(() {
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: versioningController.folderContents.length,
                      itemBuilder: (context, index) {
                        final item = versioningController.folderContents[index];

                        if (item is FolderItem) {
                          return ListTile(
                            dense: true,
                            title: Text('/${item.name}'),
                            subtitle: Text('${item.itemCount} items'),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Created: ${item.created}'),
                                Text('Modified: ${item.modified}'),
                              ],
                            ),
                            onTap: () {
                              if (item.name == '..') {
                                versioningController.goBack();
                              } else {
                                versioningController.userSelection.value = item.path;
                                versioningController.loadTarget(item.path);
                              }
                            },
                          );
                        } else if (item is FileItem) {
                          return ListTile(
                            dense: true,
                            title: Text(item.name),
                            subtitle: Text('${item.size} bytes'),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Created: ${item.created}'),
                                Text('Modified: ${item.modified}'),
                              ],
                            ),
                            onTap: () {
                              versioningController.userSelection.value = item.path;
                              Get.snackbar('File selected', item.name);
                            },
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  }),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          controller.setStamp();
          // versioningController.loadTarget(versioningController.userSettings['targetAddress']);
          final currentFolder = versioningController.currentPath;
          await versioningController.updateSetting(versioningController.userSettings['settingsAddress'], 'targetAddress', currentFolder);
          viewController.showDialog(
            'Target',
            'Current target: $currentFolder',
          );
        },
      ),
    );
  }
}