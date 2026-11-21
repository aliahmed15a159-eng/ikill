import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'field_report_store.dart';
import 'supabase_client.dart';

class FieldReportRepository {
  const FieldReportRepository();
  Future<void> submit(String tenant, String user, String visit, Map<String, dynamic> draft, FieldReportStore store, Uint8List signature) async {
    final account = await AuthService.profile();
    if (account.role != 'technician' || account.tenantId != tenant || supabaseClient.auth.currentUser?.id != user) {
      throw const AccessDenied('Assigned technician required');
    }
    final key = draft['submission'] as String;
    if (await supabaseClient.rpc('my_field_report_receipt', params: {'target_visit':visit,'submission':key}) != null) return;
    final prefix = '$tenant/$visit/$key';
    final photos = <String>[];
    for (final name in List<String>.from(draft['photos'] as List)) {
      final bytes = await (await store.photo(visit, name)).readAsBytes();
      if (bytes.length > 10485760) throw StateError('Photo exceeds 10 MB');
      final path = '$prefix/$name';
      await supabaseClient.storage.from('visit-images').uploadBinary(path, bytes, fileOptions: const FileOptions(contentType:'image/jpeg',upsert:true));
      photos.add(path);
    }
    final path = '$prefix/signature.png';
    await supabaseClient.storage.from('visit-signatures').uploadBinary(path, signature, fileOptions: const FileOptions(contentType:'image/png',upsert:true));
    await supabaseClient.rpc('submit_field_report', params: {
      'target_visit':visit,'submission':key,
      'checklist':{'pest':draft['pest'],'severity':draft['severity'],'actions':draft['actions'],'materials':draft['materials'],'signature_consent':true},
      'materials':draft['materials'],'notes':draft['notes'],'photos':photos,'signature_path':path,'signer':draft['signer'],
    });
  }
}
