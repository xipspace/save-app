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
}

class Snapshot {
  final String id;
  String title;
  String home;
  List<Map<String, dynamic>> items;

  Snapshot({required this.id, required this.title, required this.home, required this.items});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'home': home, 'items': items};

  factory Snapshot.fromJson(Map<String, dynamic> json) {
    return Snapshot(
      id: json['id'],
      title: json['title'],
      home: json['home'],
      items: List<Map<String, dynamic>>.from(json['items']),
    );
  }
}
