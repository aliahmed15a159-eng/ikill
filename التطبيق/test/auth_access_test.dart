import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikill_native/auth_service.dart';
import 'package:ikill_native/supabase_client.dart';

void main() {
  Map<String, dynamic> account(String role) => {
    'tenant_id': 'company', 'role': role, 'portal_enabled': false,
    'is_active': true, 'tenant_active': true,
  };
  test('Disabled client portal has explicit denial; enabled client allowed', () {
    final data = account('client');
    expect(ProfileAccess(data).denial, contains('بوابة العميل غير مفعّلة'));
    expect(ProfileAccess({...data, 'portal_enabled': true}).denial, isNull);
  });
  test('Staff do not need client portal flag; inactive tenants are denied', () {
    expect(ProfileAccess(account('admin')).denial, isNull);
    expect(ProfileAccess(account('technician')).denial, isNull);
    expect(ProfileAccess({...account('admin'), 'tenant_active': false}).denial, isNotNull);
    expect(ProfileAccess({...account('admin'), 'is_active': false}).denial, isNotNull);
    expect(ProfileAccess(account('unknown')).denial, isNotNull);
  });
  test('Public configuration rejects privileged client keys', () {
    String jwt(String role) => 'header.${base64Url.encode(utf8.encode(jsonEncode({'role': role})))}.signature';
    expect(SupabaseConnection.isPublicKey('sb_publishable_example'), isTrue);
    expect(SupabaseConnection.isPublicKey(jwt('anon')), isTrue);
    expect(SupabaseConnection.isPublicKey(jwt('service_role')), isFalse);
    expect(SupabaseConnection.isPublicKey('sb_secret_example'), isFalse);
    expect(SupabaseConnection.isPublicKey(''), isFalse);
  });
}
