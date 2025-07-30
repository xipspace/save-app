import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_controller.dart';
import 'app_model.dart';

enum ActionType { home, save, compress, extract }

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
    final home = Get.find<HomeController>();
    final view = Get.find<ViewController>();
    final stream = Get.find<StreamController>();
    final archive = Get.find<ArchiveController>();

    final Map<ActionType, VoidCallback> actionMap = {
      ActionType.home: () async {
        // go to home
      },
      ActionType.save: () async {
        final currentFolder = view.viewLocation;
        await stream.updateSettings(stream.settingsFilePath, 'home', currentFolder);
        await view.saveSelectedItems();
      },
      ActionType.compress: () async {
        await archive.compressTarget();
      },
      ActionType.extract: () async {
        await archive.extractTarget();
      },
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('@saveApp'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(icon: const Icon(Icons.dark_mode_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () => Get.to(() => const UserScreen())),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1024),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Obx(() => Text(home.msg.value)),
                Obx(() => Text(home.timeStamp.value)),
                // const SizedBox(height: 20),
                // Obx(() => Text(home.userSettings.toString())),
                const SizedBox(height: 20),
                
                
                
                Container(
                  alignment: Alignment.center,
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Wrap(
                    // spacing: 5,
                    // runSpacing: 5,
                    children: ActionType.values.map((action) {
                      final label = action.name.capitalizeFirst ?? action.name;
                      return SizedBox(
                        width: 150,
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias, // ensures the ripple is clipped
                            child: InkWell(
                              onTap: actionMap[action],
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                child: Center(child: Text(label)),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),


                const SizedBox(height: 20),



                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  elevation: 2,
                  child: Obx(() {
                    final items = view.viewContents;
                    if (items.isEmpty) {
                      return const Padding(padding: EdgeInsets.all(10), child: Text('This folder is empty.'));
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final displayName = item is FolderItem ? '/${item.name}' : item.name;

                        return ListTile(
                          dense: true,
                          title: Text(displayName, style: TextStyle(fontSize: 14)),
                          subtitle: item.name != '..'
                              ? Text('created: ${item.created.toString()}\nmodified: ${item.modified.toString()}')
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          trailing: item.name != '..'
                              ? Obx(
                                  () => Checkbox(
                                    value: item.isSelected.value,
                                    onChanged: (val) => item.isSelected.value = val ?? false,
                                  ),
                                )
                              : null,
                          onTap: () {
                            if (item is FolderItem) {
                              view.viewLocation = item.path;
                              view.readLocation();
                            }
                          },
                        );
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
    );
  }
}

class UserScreen extends StatelessWidget {
  const UserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController home = Get.find<HomeController>();
    final MediaQueryData mediaQueryData = MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 20),

            Obx(() => Text(home.timeStamp.value.toString())),

            const SizedBox(height: 20),
            const Text('device info'),
            const SizedBox(height: 20),
            Text('Screen Size: ${mediaQueryData.size.width} x ${mediaQueryData.size.height}'),
            Text('Orientation: ${mediaQueryData.orientation}'),
            Text('Device Pixel Ratio: ${mediaQueryData.devicePixelRatio}'),
            Text('Device Theme: ${mediaQueryData.platformBrightness}'),

            Text('GetX isDarkMode: ${Get.isDarkMode}'),
            // width: Get.width * 0.95,
            // height: Get.height * 0.95,

            const SizedBox(height: 20),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => home.setStamp(),
      ),
    );
  }
}