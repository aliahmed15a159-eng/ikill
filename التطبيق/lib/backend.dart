import 'auth_service.dart';
import 'supabase_client.dart';

/// Repository for existing screens. No database-specific SDK types escape it.
class Backend {
  static bool get ready => SupabaseConnection.ready;
  static Future<void> initialize() => SupabaseConnection.initialize();

  static Future<void> submit(Map<String, String> values) async {
    if (!ready) throw StateError('Supabase is not configured');
    await supabaseClient.rpc('submit_contact_request', params: {
      'brand_slug': SupabaseConnection.brandSlug,
      'contact_name': values['name'], 'contact_phone': values['phone'],
      'contact_email': values['email'], 'contact_address': values['address'],
      'contact_service': values['service'], 'contact_message': values['message'],
    }).timeout(const Duration(seconds: 25));
  }

  static Future<Map<String, dynamic>> publicSettings() async {
    if (!ready) return {};
    final raw = await supabaseClient.rpc('get_public_brand', params: {'brand_slug': SupabaseConnection.brandSlug});
    if (raw == null) return {};
    return Map<String, dynamic>.from((raw as Map)['branding'] as Map? ?? {});
  }

  static Map<String, dynamic> branchToScreen(Map<String, dynamic> row) => {
    ...row, 'nameAr': row['name_ar'], 'nameEn': row['name_en'],
    'countryAr': row['country_ar'], 'countryEn': row['country_en'],
  };

  static Future<List<Map<String, dynamic>>> publicBranches() async {
    if (!ready) return [];
    final rows = await supabaseClient.rpc('get_public_branches', params: {'brand_slug': SupabaseConnection.brandSlug});
    return (rows as List).map((r) => branchToScreen(Map<String, dynamic>.from(r as Map))).toList();
  }

  static Future<List<Map<String, dynamic>>> records(int tab) async {
    final account = await AuthService.requireAdmin();
    final table = tab == 0 ? 'clients' : tab == 1 ? 'company_branches' : 'page_events';
    final rows = await supabaseClient.from(table).select().eq('tenant_id', account.tenantId).order('created_at', ascending: false);
    return rows.map((row) => tab == 1 ? branchToScreen(row) : {
      ...row, 'name': row['display_name'], 'address': row['billing_address'],
      'service': row['requested_service'], 'message': row['request_message'],
      'timestamp': row['created_at'],
    }).toList();
  }

  static Future<void> deleteRecord(int tab, String id) async {
    final account = await AuthService.requireAdmin();
    final table = tab == 0 ? 'clients' : tab == 1 ? 'company_branches' : 'page_events';
    await supabaseClient.from(table).delete().eq('tenant_id', account.tenantId).eq('id', id);
  }

  static Future<void> saveBranch(Map<String, String> values, {String? id}) async {
    final account = await AuthService.requireAdmin();
    final row = <String, dynamic>{
      'tenant_id': account.tenantId, 'name_ar': values['nameAr'], 'name_en': values['nameEn'],
      'country_ar': values['countryAr'], 'country_en': values['countryEn'],
      'phone': values['phone'], 'status': values['status'],
    };
    if (id == null) {
      await supabaseClient.from('company_branches').insert(row);
    } else {
      await supabaseClient.from('company_branches').update(row).eq('tenant_id', account.tenantId).eq('id', id);
    }
  }

  static Future<Map<String, dynamic>> adminSettings() async {
    final account = await AuthService.requireAdmin();
    final row = await supabaseClient.from('tenants').select('branding').eq('id', account.tenantId).single();
    return Map<String, dynamic>.from(row['branding'] as Map);
  }

  static Future<void> saveSettings(Map<String, String> values) async {
    final account = await AuthService.requireAdmin();
    final current = await adminSettings();
    await supabaseClient.from('tenants').update({'branding': {...current, ...values},
      'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', account.tenantId);
  }
}
