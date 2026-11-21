import 'auth_service.dart';
import 'supabase_client.dart';

class ClientRepository {
  const ClientRepository();
  Future<List<Map<String, dynamic>>> clients() async {
    final a = await AuthService.requireAdmin();
    return supabaseClient.from('clients').select().eq('tenant_id', a.tenantId).order('created_at', ascending: false).limit(1000);
  }
  Future<void> addClient(String id, Map<String, String> fields) async {
    final a = await AuthService.requireAdmin();
    await supabaseClient.from('clients').upsert({'id': id, 'tenant_id': a.tenantId, 'client_code': id,
      'display_name': fields['name'], 'contact_name': fields['contact'], 'phone': fields['phone'], 'email': fields['email'],
      'client_type': 'contract', 'status': 'survey_pending'}, onConflict: 'id', ignoreDuplicates: true);
  }
  Future<Map<String, dynamic>> detail(String id) async {
    final a = await AuthService.requireAdmin();
    final customer = await supabaseClient.from('clients').select().eq('tenant_id', a.tenantId).eq('id', id).single();
    final sites = await supabaseClient.from('client_sites').select().eq('tenant_id', a.tenantId).eq('client_id', id).order('created_at');
    final surveys = await supabaseClient.from('surveys').select().eq('tenant_id', a.tenantId).eq('client_id', id).order('created_at', ascending: false);
    final contracts = await supabaseClient.from('contracts').select().eq('tenant_id', a.tenantId).eq('client_id', id).order('created_at', ascending: false);
    final plans = await supabaseClient.from('contract_site_plans').select().eq('tenant_id', a.tenantId).eq('client_id', id);
    return {'client': customer, 'sites': sites, 'surveys': surveys, 'contracts': contracts, 'plans': plans};
  }
  Future<void> saveSite(String clientId, String id, Map<String, String> fields) async {
    final a = await AuthService.requireAdmin();
    await supabaseClient.from('client_sites').upsert({'id': id, 'tenant_id': a.tenantId, 'client_id': clientId,
      'name': fields['name'], 'address': fields['address'], 'sector': fields['sector'], 'contact_phone': fields['phone'],
      'latitude': num.parse(fields['latitude']!), 'longitude': num.parse(fields['longitude']!)}, onConflict: 'id');
  }
  Future<void> saveSurvey(String clientId, String siteId, String surveyId, Map<String, String> fields) async {
    final a = await AuthService.requireAdmin();
    final company = await supabaseClient.from('tenants').select('currency').eq('id', a.tenantId).single();
    await supabaseClient.from('surveys').upsert({'id': surveyId, 'tenant_id': a.tenantId, 'client_id': clientId,
      'site_id': siteId, 'status': 'completed', 'surveyed_at': DateTime.now().toUtc().toIso8601String(),
      'surveyor_id': supabaseClient.auth.currentUser!.id, 'assessment': {'findings': fields['findings'], 'site_details': fields['details']},
      'proposed_total': fields['price'], 'currency': company['currency']}, onConflict: 'id');
  }
  Future<void> saveContract(String id, String clientId, Map<String, dynamic> values) async {
    await AuthService.requireAdmin();
    await supabaseClient.rpc('save_client_contract', params: {'contract_id': id, 'customer_id': clientId,
      'starts': values['start'], 'ends': values['end'], 'total': values['total'], 'cycle': values['cycle'], 'plans': values['plans']});
  }
  Future<int> activate(String id, String signer, String reference) async {
    await AuthService.requireAdmin();
    return await supabaseClient.rpc('activate_client_contract', params: {'contract_id': id, 'signer': signer, 'reference': reference}) as int;
  }
  Future<List<Map<String, dynamic>>> visits(String clientId, int offset) async {
    final a = await AuthService.requireAdmin();
    return supabaseClient.from('visits').select('*,client_sites(name)').eq('tenant_id', a.tenantId).eq('client_id', clientId)
      .not('contract_id', 'is', null).order('scheduled_start').order('id').range(offset, offset + 99);
  }
  Future<void> reschedule(String id, DateTime start, DateTime end, String? technician) async {
    await AuthService.requireAdmin();
    await supabaseClient.rpc('reschedule_contract_visit', params: {'visit_id': id, 'starts': start.toUtc().toIso8601String(),
      'ends': end.toUtc().toIso8601String(), 'technician': technician});
  }
}
