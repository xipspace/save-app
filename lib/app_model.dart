import 'package:get/get.dart';

abstract class FileObject {
  final String name;
  final String path;
  final DateTime created;
  final DateTime modified;
  final RxBool isSelected = false.obs;

  final bool isSpecial;
  final bool isDrive;

  FileObject({
    required this.name,
    required this.path,
    required this.created,
    required this.modified,
    this.isSpecial = false,
    this.isDrive = false,
  });

  String get identitySignature => '$path|$created';

  Map<String, dynamic> toJson();

  factory FileObject.fromJson(Map<String, dynamic> json) {
    if (json['type'] == 'folder') {
      return FolderItem(
        name: json['name'],
        path: json['path'],
        created: DateTime.parse(json['created']),
        modified: DateTime.parse(json['modified']),
        itemCount: json['itemCount'] ?? 0,
        isSpecial: json['isSpecial'] ?? false,
        isDrive: json['isDrive'] ?? false,
      )..isSelected.value = json['isSelected'] ?? false;
    } else {
      return FileItem(
        name: json['name'],
        path: json['path'],
        created: DateTime.parse(json['created']),
        modified: DateTime.parse(json['modified']),
        size: json['size'] ?? 0,
        extension: json['extension'] ?? '',
        isSpecial: json['isSpecial'] ?? false,
        isDrive: json['isDrive'] ?? false,
      )..isSelected.value = json['isSelected'] ?? false;
    }
  }
}

class FileItem extends FileObject {
  final int size;
  final String extension;

  FileItem({
    required super.name,
    required super.path,
    required super.created,
    required super.modified,
    required this.size,
    required this.extension,
    super.isSpecial = false,
    super.isDrive = false,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'file',
    'name': name,
    'path': path,
    'created': created.toIso8601String(),
    'modified': modified.toIso8601String(),
    'size': size,
    'extension': extension,
    'isSpecial': isSpecial,
    'isDrive': isDrive,
    'isSelected': isSelected.value,
  };
}

class FolderItem extends FileObject {
  final int itemCount;

  FolderItem({
    required super.name,
    required super.path,
    required super.created,
    required super.modified,
    required this.itemCount,
    super.isSpecial = false,
    super.isDrive = false,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'folder',
    'name': name,
    'path': path,
    'created': created.toIso8601String(),
    'modified': modified.toIso8601String(),
    'itemCount': itemCount,
    'isSpecial': isSpecial,
    'isDrive': isDrive,
    'isSelected': isSelected.value,
  };
}

class Snapshot {
  final String id;
  String title;
  String home;
  List<FileObject> items;

  Snapshot({required this.id, required this.title, required this.home, required this.items});

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'home': home,
    'items': items.map((e) => e.toJson()).toList(),
  };

  factory Snapshot.fromJson(Map<String, dynamic> json) {
    return Snapshot(
      id: json['id'],
      title: json['title'],
      home: json['home'],
      items: (json['items'] as List).map((e) => FileObject.fromJson(e)).toList(),
    );
  }
}
