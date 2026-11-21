import 'auth_service.dart';
import 'instapay_service.dart';
import 'backend.dart';
import 'request_models.dart';
import 'supabase_client.dart';

/// Narrow app-only RPCs; does not change the website's contact request flow.
class RequestRepository {
  const RequestRepository();
  bool get ready => Backend.ready;
  Future<InstapayDestination?> paymentDestination() => InstapayService.published().timeout(const Duration(seconds: 20));

  Future<ResidentialQuote?> quote(String property, String problem) async {
    if (!ready) return null;
    final row = await supabaseClient.rpc('get_residential_quote', params: {
      'brand_slug': SupabaseConnection.brandSlug, 'property': property, 'problem': problem,
    }).timeout(const Duration(seconds: 20));
    return row == null ? null : ResidentialQuote.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<Map<String, dynamic>> submit(String requestId, Map<String, dynamic> payload) async {
    final row = await supabaseClient.rpc('submit_app_request', params: {
      'brand_slug': SupabaseConnection.brandSlug, 'request_id': requestId, 'payload': payload,
    }).timeout(const Duration(seconds: 30));
    return Map<String, dynamic>.from(row as Map);
  }

  Future<List<Map<String, dynamic>>> prices() async {
    final account = await AuthService.requireAdmin();
    final service = await supabaseClient.from('services_catalog').select('id')
      .eq('tenant_id', account.tenantId).eq('code', 'residential_pest').maybeSingle();
    if (service == null) return [];
    return supabaseClient.from('pricing_matrix').select().eq('tenant_id', account.tenantId)
      .eq('service_id', service['id']);
  }

  Future<void> savePrice(String property, String problem, String amount, bool enabled) async {
    await AuthService.requireAdmin();
    await supabaseClient.rpc('save_residential_price', params: {
      'property': property, 'problem': problem, 'amount': amount, 'enabled': enabled,
    });
  }

  Future<List<Map<String, dynamic>>> pending(bool survey) async {
    final account = await AuthService.requireAdmin();
    return supabaseClient.from(survey ? 'surveys' : 'visits')
      .select('*,clients(display_name,contact_name,phone,email),client_sites(name,address,latitude,longitude)')
      .eq('tenant_id', account.tenantId).eq('status', survey ? 'survey_pending' : 'pending_schedule')
      .order('created_at');
  }

  Future<List<Map<String, dynamic>>> technicians() async {
    final account = await AuthService.requireAdmin();
    return supabaseClient.from('profiles').select('id,full_name').eq('tenant_id', account.tenantId)
      .eq('role', 'technician').eq('is_active', true);
  }

  Future<void> reviewPayment(String visitId, bool approved) async {
    await AuthService.requireAdmin();
    await supabaseClient.rpc('review_residential_payment', params: {'visit_id': visitId, 'approved': approved});
  }

  Future<void> schedule(String visitId, DateTime start, DateTime end, String technicianId) async {
    await AuthService.requireAdmin();
    await supabaseClient.rpc('schedule_app_visit', params: {
      'visit_id': visitId, 'starts_at': start.toUtc().toIso8601String(),
      'ends_at': end.toUtc().toIso8601String(), 'assigned_technician': technicianId,
    });
  }
}
