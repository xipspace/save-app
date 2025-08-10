import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_controller.dart';
import 'app_model.dart';

enum ActionType { home, refresh, add, restore }

void main() => runApp(const MainApp());

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'saveApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
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
    // final stream = Get.find<StreamController>();
    final archive = Get.find<ArchiveController>();

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
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Obx(() => Text(home.msg.value)),
                Obx(() => Text(home.timeStamp.value)),

                const SizedBox(height: 20),

                // be able to edit targets of a current snapshot
                // revert from a specific archive or the last one
                // save and restore triggered by global HK and interval
                Obx(() {
                  final entries = home.snapshots.entries.toList();

                  return entries.isEmpty
                      ? const Text('No snapshots available. Add one.')
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final snapshotId = entry.key;
                            final snapshot = entry.value;

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
                                          Text(snapshot.title),
                                          const Spacer(),
                                          Row(
                                            children: [
                                              Tooltip(
                                                message: 'compress',
                                                child: IconButton(
                                                  iconSize: 18,
                                                  icon: const Icon(Icons.add),
                                                  onPressed: () async {
                                                    home.setMsg('saved');
                                                    home.setStamp();
                                                    await archive.compressTarget(snapshot);
                                                  },
                                                ),
                                              ),
                                              // TODO > read storage and identify any container and target last as default
                                              // read container contents
                                              Tooltip(
                                                message: 'restore',
                                                child: IconButton(
                                                  iconSize: 18,
                                                  icon: const Icon(Icons.replay),
                                                  onPressed: () {
                                                    // and pass the home of the targets to reverse
                                                    // archive.extractTarget();
                                                  },
                                                ),
                                              ),
                                              Tooltip(
                                                message: 'edit',
                                                child: IconButton(
                                                  iconSize: 18,
                                                  icon: const Icon(Icons.edit_note),
                                                  onPressed: () => home.showEdit(snapshot),
                                                ),
                                              ),
                                              Tooltip(
                                                message: 'delete',
                                                child: IconButton(
                                                  iconSize: 18,
                                                  icon: const Icon(Icons.close),
                                                  onPressed: () => home.snapshots.remove(snapshotId),
                                                ),
                                              )
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
                                      Text('id: $snapshotId'),
                                      Text('filename: ${snapshot.name}'),
                                      Text('storage: ${snapshot.storage}'),
                                      Text('home: ${snapshot.home}'),
                                      Text('items: ${snapshot.items.length}'),

                                      const SizedBox(height: 5),

                                      ...snapshot.items.map(
                                        (item) => Text(' item: ${item.path}', style: TextStyle(fontSize: 12)),
                                      ),
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
        onPressed: () async {
          // abstract logic to handle initialization using home
          // find place to expand both new additions (without a home) and edit snapshot items when going to explorer
          // TODO > clear view for a new addition and read selected target to draw view properly for edition
          view.initView();
          Get.to(() => ExplorerScreen());
        },
      ),
    );
  }
}

class ExplorerScreen extends StatelessWidget {
  const ExplorerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final home = Get.find<HomeController>();
    final view = Get.find<ViewController>();
    final stream = Get.find<StreamController>();
    // final archive = Get.find<ArchiveController>();

    final Map<ActionType, VoidCallback> actionMap = {
      ActionType.home: () async {
        // go to home
        final savedHome = home.userSettings['home'];
        if (savedHome is String && savedHome.isNotEmpty) {
          view.viewLocation = savedHome;
          view.currentDisk.value = savedHome.substring(0, 3);
          await view.readLocation();
        } else {
          home.showDialog('Home Error', 'No valid home path set.');
        }
      },
      ActionType.refresh: () async {
        await view.readLocation();
      },
      ActionType.add: () async {
        final currentFolder = view.viewLocation;
        await stream.updateSettings(stream.settingsFilePath, 'home', currentFolder);
        await view.saveSelectedItems();
        for (var item in view.viewContents) {
          item.isSelected.value = false;
        }
        home.userSettings['selection'] = [];
        await stream.updateSettings(stream.settingsFilePath, 'selection', []);
      },
    };

    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 20),

              Obx(() => Text(home.msg.value.toString())),
              Obx(() => Text(home.timeStamp.value.toString())),

              const SizedBox(height: 20),

              Container(
                alignment: Alignment.center,
                constraints: const BoxConstraints(maxWidth: 500),
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

              Obx(() => Text(home.userSettings['selection'].toString())),

              const SizedBox(height: 20),

              Obx(() {
                final disks = view.availableDisks;

                return disks.isEmpty
                    ? const Text('No disks found')
                    : DropdownButtonHideUnderline(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                          child: DropdownButton<String>(
                            value: disks.contains(view.currentDisk.value) ? view.currentDisk.value : disks.first,
                            dropdownColor: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            style: const TextStyle(fontSize: 16, color: Colors.black),
                            items: disks.map((disk) {
                              return DropdownMenuItem(value: disk, child: Text(disk));
                            }).toList(),
                            onChanged: (newDisk) {
                              if (newDisk != null) {
                                view.changeDisk(newDisk);
                              }
                            },
                          ),
                        ),
                      );
              }),

              // Obx(() => Text(home.userTree.toString())),
              const SizedBox(height: 20),

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
                                    subtitle: item.name != '..'
                                        ? Text('created: ${item.created}\nmodified: ${item.modified}')
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
                                  ),
                                ),
                              );
                            },
                          );
                  }),
                ),
              ),

              const SizedBox(height: 20),
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

              Obx(() => Text(home.msg.value.toString())),
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
      floatingActionButton: FloatingActionButton(child: const Icon(Icons.add), onPressed: () => home.setStamp()),
    );
  }
}
