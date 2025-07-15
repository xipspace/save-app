abstract class FileObject {
  final String name;
  final String path;
  final DateTime created;
  final DateTime modified;

  FileObject({
    required this.name,
    required this.path,
    required this.created,
    required this.modified,
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
  });
}
