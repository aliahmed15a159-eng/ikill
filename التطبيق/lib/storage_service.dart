import 'dart:math';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'supabase_client.dart';

/// Private storage API for existing/future file callers, without adding screens.
/// No public URLs. PostgreSQL policies remain the authority for each operation.
class StorageService {
  static const buckets = {'visit-images', 'visit-signatures', 'invoice-pdfs'};
  static final _random = Random.secure();

  static Future<String> upload({required String bucket, required String documentId,
      required Uint8List bytes, required String contentType}) async {
    if (!buckets.contains(bucket)) throw ArgumentError('Unsupported bucket');
    final account = await AuthService.profile();
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(documentId)) {
      throw ArgumentError('Invalid document id');
    }
    const extensions = {'image/png': 'png', 'image/jpeg': 'jpg', 'image/webp': 'webp', 'application/pdf': 'pdf'};
    final extension = extensions[contentType];
    final validType = bucket == 'visit-signatures' ? contentType == 'image/png'
      : bucket == 'invoice-pdfs' ? contentType == 'application/pdf'
      : ['image/png', 'image/jpeg', 'image/webp'].contains(contentType);
    if (extension == null || !validType || bytes.isEmpty) throw ArgumentError('Invalid file type or empty file');
    final maxSize = bucket == 'visit-signatures' ? 2 : bucket == 'invoice-pdfs' ? 20 : 10;
    if (bytes.length > maxSize * 1024 * 1024) throw ArgumentError('File is too large');
    final randomName = List.generate(24, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final path = '${account.tenantId}/$documentId/$randomName.$extension';
    await supabaseClient.storage.from(bucket).uploadBinary(path, bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: false));
    return path;
  }

  static Future<String> signedUrl(String bucket, String path) async {
    if (!buckets.contains(bucket)) throw ArgumentError('Unsupported bucket');
    await AuthService.profile();
    return supabaseClient.storage.from(bucket).createSignedUrl(path, 60);
  }

  static Future<void> remove(String bucket, String path) async {
    if (!buckets.contains(bucket)) throw ArgumentError('Unsupported bucket');
    await AuthService.profile();
    await supabaseClient.storage.from(bucket).remove([path]);
  }
}
