import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

String reportSubmissionKey() => List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join();

/// App-private persistent files, never camera cache paths. A complete JSON
/// snapshot is flushed before atomic rename. Saves are serialized by the form.
class FieldReportStore {
  final Directory root;
  FieldReportStore(this.root);
  static Future<FieldReportStore> open(String tenant, String user) async {
    final base = await getApplicationSupportDirectory();
    return FieldReportStore(Directory('${base.path}/field-reports/$tenant/$user'));
  }
  Future<Directory> visitDirectory(String visit) async {
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(visit)) throw ArgumentError('Invalid visit');
    return Directory('${root.path}/$visit').create(recursive: true);
  }
  Future<void> writeJson(String name, Object value) async {
    await root.create(recursive: true);
    final file = File('${root.path}/$name');
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(value), flush: true);
    await temp.rename(file.path);
  }
  Future<dynamic> readJson(String name) async {
    final file = File('${root.path}/$name');
    if (!await file.exists()) return null;
    return jsonDecode(await file.readAsString());
  }
  Future<Map<String, dynamic>?> load(String visit) async {
    final value = await readJson('$visit/draft.json');
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }
  Future<void> save(String visit, Map<String, dynamic> draft) async {
    await visitDirectory(visit); await writeJson('$visit/draft.json', draft);
  }
  Future<String> keepPhoto(String visit, String source) async {
    final directory = await visitDirectory(visit);
    final name = 'photo-${reportSubmissionKey()}.jpg';
    await File(source).copy('${directory.path}/$name');
    return name;
  }
  Future<File> photo(String visit, String name) async {
    if (!RegExp(r'^photo-[a-f0-9]{32}\.jpg$').hasMatch(name)) throw ArgumentError('Invalid photo');
    return File('${(await visitDirectory(visit)).path}/$name');
  }
  Future<void> remove(String visit) async {
    final directory = await visitDirectory(visit);
    await directory.delete(recursive: true);
  }
}
