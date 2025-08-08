import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_controller.dart';
import 'app_model.dart';

enum ActionType { home, refresh, add, restore, compress, extract }

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
    final home = Get.find<HomeController>();
    final view = Get.find<ViewController>();
    final stream = Get.find<StreamController>();
    final archive = Get.find<ArchiveController>();

    final Map<ActionType, VoidCallback> actionMap = {
      ActionType.home: () async {
        // go to home
        final savedHome = home.userSettings['home'];
        if (savedHome is String && savedHome.isNotEmpty) {
          view.viewLocation = savedHome;
          await view.readLocation();
        } else {
          home.showDialog('Home Error', 'No valid home path set.');
        }
        // home.showDialog('Home', home.userSettings['home'].toString());
        // home.showDialog('Tree', home.userSettings['tree'].toString());
      },
      ActionType.refresh: () async {
        await view.readLocation();
      },
      ActionType.add: () async {
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



                const SizedBox(height: 20),


                // game needs to have a default place to archive (home), the top watched folder, and be customizable
                // revert from a specific archive or the last one
                // save and restore triggered by global HK and interval


                Obx(() {
                  final entries = home.userTree.entries.toList();

                  return entries.isEmpty
                      ? const Text('No snapshots available.')
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final timestamp = entry.key;
                            final List snapshot = entry.value;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                              elevation: 2.0,
                              child: ListTile(
                                title: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5.0),
                                      child: Row(
                                        children: [
                                          Text(timestamp),
                                          const Spacer(),
                                          Row(
                                            children: [
                                              IconButton(
                                                iconSize: 18,
                                                icon: const Icon(Icons.add),
                                                onPressed: () {},
                                              ),
                                              IconButton(
                                                iconSize: 18,
                                                icon: const Icon(Icons.replay),
                                                onPressed: () {},
                                              ),
                                              IconButton(
                                                iconSize: 18,
                                                icon: const Icon(Icons.edit_note),
                                                onPressed: () {},
                                              ),
                                              IconButton(
                                                iconSize: 18,
                                                icon: const Icon(Icons.close),
                                                onPressed: () => home.userTree.remove(timestamp),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(),
                                  ],
                                ),
                                subtitle: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 5.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Items: ${snapshot.length}'),
                                      // Text('Target: ${home.userTree.entries.toList()}'),
                                      Text('Target: ${snapshot.map((item) => item).join('\n')}'),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                }),


                // const SizedBox(height: 20),
                
                

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => Get.to(ExplorerScreen()),
      ),
    );
  }
}

class ExplorerScreen extends StatelessWidget {
  const ExplorerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final home = Get.find<HomeController>();
    final view = Get.find<ViewController>();
    final stream = Get.find<StreamController>();
    final archive = Get.find<ArchiveController>();

    final Map<ActionType, VoidCallback> actionMap = {
      ActionType.home: () async {
        // go to home
        final savedHome = home.userSettings['home'];
        if (savedHome is String && savedHome.isNotEmpty) {
          view.viewLocation = savedHome;
          await view.readLocation();
        } else {
          home.showDialog('Home Error', 'No valid home path set.');
        }
        // home.showDialog('Home', home.userSettings['home'].toString());
        // home.showDialog('Tree', home.userSettings['tree'].toString());
      },
      ActionType.refresh: () async {
        await view.readLocation();
      },
      ActionType.add: () async {
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
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 20),
        
              Obx(() => Text(home.timeStamp.value.toString())),
        
              const SizedBox(height: 20),
              const Text('device info'),
              const SizedBox(height: 20),
              Text('Screen Size: ${media.size.width} x ${media.size.height}'),
              Text('Orientation: ${media.orientation}'),
              Text('Device Pixel Ratio: ${media.devicePixelRatio}'),
              Text('Device Theme: ${media.platformBrightness}'),
        
              Text('GetX isDarkMode: ${Get.isDarkMode}'),
              // width: Get.width * 0.95,
              // height: Get.height * 0.95,
        
              const SizedBox(height: 20),
        
              Obx(() => Text(home.userSettings['selection'].toString())),
              // Obx(() => Text(home.userTree.toString())),
              
              Container(
                  alignment: Alignment.center,
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Wrap(
                    // spacing: 5,
                    // runSpacing: 5,
                    children: ActionType.values.map((action) {
                      final label = action.name.capitalizeFirst ?? action.name;
                      return SizedBox(
                        width: 100,
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Material(
                            color: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

              // add dynamic list with traling checkboxes as file explorer using readLocation, dont use icons
              // folders first files after
              // use a '..' to navigateTo parent
              // use a '/' as prefix in the view to indicate a folder and the parent folder '..', except drivers, we still need '..' in a root folder because it travels us to the driver list
              // traveling parent from a root folder shows the driver list so user can select which driver to navigateTo
              // adjust the model to properly handles drivers as C:
              // dont show metadata for '..' or drivers
              // dont show checkboxes for drivers
              // the checkboxes will update userSettings.selection after calling saveSelectedItems
              // tap on a folder / driver / .. navigateTo() , tap on a file does nothing (later will be a call)
              // add error handling for cases where the directory or file cannot be accessed due to permissions issues
              // root contents isnt the same as driver list
              // map the list in a dropdown for selection

              Card(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Material(
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: Obx(() {
                    final items = view.viewContents;

                    return items.isEmpty
                        ? const Text('This folder is empty.')
                        // add list from here
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final isDrive =
                                  item is FolderItem && RegExp(r'^[A-Z]:\\$', caseSensitive: false).hasMatch(item.name);
                              final displayName = item is FolderItem && !item.name.contains(':')
                                  ? '/${item.name}'
                                  : item.name;

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    if (item is FolderItem) {
                                      view.viewLocation = item.path;
                                      view.readLocation();
                                    }
                                  },
                                  child: ListTile(
                                    dense: true,
                                    title: Text(displayName, style: const TextStyle(fontSize: 14)),
                                    subtitle: (!isDrive && item.name != '..')
                                        ? Text('created: ${item.created}\nmodified: ${item.modified}')
                                        : null,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    trailing: (!isDrive && item.name != '..')
                                        ? Obx(
                                            () => Checkbox(
                                              value: item.isSelected.value,
                                              onChanged: (val) => item.isSelected.value = val ?? false,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            },
                          );
                  }),
                ),
              ),
            ],
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
    final MediaQueryData media = MediaQuery.of(context);
    final home = Get.find<HomeController>();

    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 20),
        
              Obx(() => Text(home.timeStamp.value.toString())),
        
              const SizedBox(height: 20),
              const Text('device info'),
              const SizedBox(height: 20),
              Text('Screen Size: ${media.size.width} x ${media.size.height}'),
              Text('Orientation: ${media.orientation}'),
              Text('Device Pixel Ratio: ${media.devicePixelRatio}'),
              Text('Device Theme: ${media.platformBrightness}'),
        
              Text('GetX isDarkMode: ${Get.isDarkMode}'),
              // width: Get.width * 0.95,
              // height: Get.height * 0.95,
        
              const SizedBox(height: 20),
        
              Obx(() => Text(home.userSettings['selection'].toString())),
              // Obx(() => Text(home.userTree.toString())),



              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => home.setStamp(),
      ),
    );
  }
}