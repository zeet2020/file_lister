import 'package:isar/isar.dart';

part 'configurations.g.dart';

@collection
class Record {
  Id id = Isar.autoIncrement;
  @Index()
  late String name;

  @Index(unique: true, replace: true)
  late String path;

  late int size;
  late DateTime modified;
  late String ext;
}

@collection
class Configurations {
  Id id = Isar.autoIncrement;
  late List<String> scan_path;
  late String file_ext;
}
