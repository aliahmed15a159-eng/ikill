import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'supabase_client.dart';
import 'lifecycle_forms.dart';

class OperationsSubscription {
  final Future<void> Function() close;
  const OperationsSubscription(this.close);
}
class OperationsRepository {
  const OperationsRepository();
  Future<Map<String, dynamic>> summary() async {
    await AuthService.requireAdmin();
    return Map<String, dynamic>.from(await supabaseClient.rpc('get_operations_summary') as Map);
  }
  Future<Map<String, dynamic>> contextData() async {
    await AuthService.requireAdmin();
    return Map<String, dynamic>.from(await supabaseClient.rpc('get_operations_context') as Map);
  }
  Future<List<Map<String, dynamic>>> visits(DateTime first, DateTime last, {String? client, String? site, String? technician}) async {
    await AuthService.requireAdmin();
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 250) {
      final result = await supabaseClient.rpc('get_operations_visits', params: {'first_day': isoDay(first), 'last_day': isoDay(last),
        'customer': client, 'site': site, 'technician': technician, 'page_offset': offset}) as List;
      rows.addAll(result.map((r) => Map<String, dynamic>.from(r as Map)));
      if (result.length < 250) return rows;
    }
  }
  Future<void> assign(String id, String? technician) async {
    await AuthService.requireAdmin();
    await supabaseClient.rpc('assign_operations_technician', params: {'visit_id': id, 'technician': technician});
  }
  Future<int> assignSite(String id, String? technician) async {
    await AuthService.requireAdmin();
    return await supabaseClient.rpc('assign_site_technician', params: {'site_id': id, 'technician': technician}) as int;
  }
  Future<OperationsSubscription> watch(String tenant, void Function() changed, void Function(bool) connection) async {
    await AuthService.requireAdmin();
    final channel = supabaseClient.channel('operations-$tenant-${DateTime.now().microsecondsSinceEpoch}');
    for (final table in ['visits','surveys','contracts','invoices','clients','client_sites','profiles']) {
      channel.onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: table,
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'tenant_id', value: tenant), callback: (_) => changed());
    }
    channel.subscribe((status, error) { connection(status == RealtimeSubscribeStatus.subscribed); });
    return OperationsSubscription(() async { await supabaseClient.removeChannel(channel); });
  }
}
