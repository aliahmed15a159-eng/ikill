import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Public/publishable key ONLY. Authorization always comes from PostgreSQL RLS.
SupabaseClient get supabaseClient => Supabase.instance.client;

class SupabaseConnection {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const brandSlug = String.fromEnvironment('BRAND_SLUG', defaultValue: 'ikill');
  static bool ready = false;
  static bool isPublicKey(String key) {
    if (key.startsWith('sb_publishable_')) return true;
    try {
      final parts = key.split('.');
      if (parts.length != 3) return false;
      final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map;
      return claims['role'] == 'anon';
    } catch (_) { return false; }
  }
  static Future<void> initialize() async {
    if (url.isEmpty || anonKey.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
    // Never accept a privileged JWT/secret key as client configuration.
    if (!isPublicKey(anonKey)) return;
    try {
      await Supabase.initialize(url: url, anonKey: anonKey, debug: false,
        authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce, detectSessionInUri: false));
      ready = true;
    } catch (_) {
      ready = false;
    }
  }
}
