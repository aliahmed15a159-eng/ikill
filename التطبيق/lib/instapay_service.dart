import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'request_models.dart';
import 'supabase_client.dart';

class InstapayDestination {
  final String path, beneficiary;
  final Uint8List image;
  const InstapayDestination(this.path, this.beneficiary, this.image);
}

class InstapayService {
  static Future<InstapayDestination?> published() async {
    final raw = await supabaseClient.rpc('get_instapay_settings', params: {'brand_slug': SupabaseConnection.brandSlug});
    if (raw == null) return null;
    final row = Map<String, dynamic>.from(raw as Map);
    final path = row['qr_path'] as String;
    final bytes = await supabaseClient.storage.from('instapay-qr').download(path);
    return InstapayDestination(path, row['beneficiary_name'] as String, bytes);
  }

  static Future<Map<String, dynamic>?> adminSettings() async {
    final admin = await AuthService.requireAdmin();
    return supabaseClient.from('app_payment_settings').select().eq('tenant_id', admin.tenantId).maybeSingle();
  }

  static String? imageType(Uint8List bytes) {
    if (bytes.length < 8 || bytes.length > 5 * 1024 * 1024) return null;
    if (bytes[0] == 137 && bytes[1] == 80 && bytes[2] == 78 && bytes[3] == 71 &&
        bytes[4] == 13 && bytes[5] == 10 && bytes[6] == 26 && bytes[7] == 10) { return 'image/png'; }
    if (bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255) return 'image/jpeg';
    return null;
  }

  static Future<Uint8List> preview(String path) async {
    await AuthService.requireAdmin();
    return supabaseClient.storage.from('instapay-qr').download(path);
  }

  static Future<String> upload(Uint8List bytes) async {
    final admin = await AuthService.requireAdmin();
    final type = imageType(bytes);
    if (type == null) throw ArgumentError('Use PNG/JPEG up to 5 MB');
    final path = '${admin.tenantId}/${newRequestId()}.${type == 'image/png' ? 'png' : 'jpg'}';
    await supabaseClient.storage.from('instapay-qr').uploadBinary(path, bytes,
      fileOptions: FileOptions(contentType: type, upsert: false));
    return path;
  }

  static Future<void> save(String? path, String beneficiary, bool enabled) async {
    await AuthService.requireAdmin();
    await supabaseClient.rpc('save_instapay_settings', params: {
      'object_path': path, 'beneficiary': beneficiary.trim(), 'is_enabled': enabled,
    });
  }
}
