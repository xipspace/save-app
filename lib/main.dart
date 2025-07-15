import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_controller.dart';
import 'app_model.dart';

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
    final versioningController = Get.find<VersioningController>();

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
                // Obx(() => Text(versioningController.folderContents.toString())),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  child: Obx(() {
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: versioningController.folderContents.length,
                      itemBuilder: (context, index) {
                        final item = versioningController.folderContents[index];

                        if (item is FolderItem) {
                          return ListTile(
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
                              versioningController.userSelection.value = item.path;
                              Get.snackbar('folder selected', item.name);
                            },
                          );
                        } else if (item is FileItem) {
                          return ListTile(
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
                              Get.snackbar('file Selected', item.name);
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
        onPressed: () {
          controller.setStamp();
          versioningController.loadTarget(versioningController.userSettings['targetAddress']);
        },
      ),
    );
  }
}