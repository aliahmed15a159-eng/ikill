import 'push_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

class ProfileAccess {
  final Map<String, dynamic> data;
  const ProfileAccess(this.data);
  String get role => data['role'] as String? ?? '';
  String get tenantId => data['tenant_id'] as String? ?? '';
  String? get denial {
    if (data['is_active'] != true || data['tenant_active'] != true) {
      return 'الحساب أو الشركة غير مفعّل / Account or company is inactive.';
    }
    if (!['admin', 'technician', 'client'].contains(role) || tenantId.isEmpty) {
      return 'لا توجد صلاحية حساب معتمدة / Account profile is not provisioned.';
    }
    if (role == 'client' && data['portal_enabled'] != true) {
      return 'بوابة العميل غير مفعّلة لحسابك. تواصل مع الإدارة / Your client portal is disabled. Contact administration.';
    }
    return null;
  }
}

class AccessDenied implements Exception {
  final String message;
  const AccessDenied(this.message);
  @override
  String toString() => message;
}

class AuthService {
  static String? lastDenial;
  static Future<ProfileAccess> profile() async {
    if (supabaseClient.auth.currentSession == null) {
      throw const AccessDenied('سجّل الدخول أولاً / Sign in first.');
    }
    // RPC returns only the caller's own account status even if portal is off.
    final raw = await supabaseClient.rpc('get_my_profile');
    if (raw == null) {
      throw const AccessDenied('لم تُنشأ صلاحيات حسابك بعد. تواصل مع الإدارة / Your account profile has not been provisioned.');
    }
    final result = ProfileAccess(Map<String, dynamic>.from(raw as Map));
    if (result.denial != null) throw AccessDenied(result.denial!);
    return result;
  }

  static Future<ProfileAccess> signIn(String email, String password) async {
    lastDenial = null;
    await supabaseClient.auth.signInWithPassword(email: email, password: password);
    try {
      return await profile();
    } catch (e) {
      if (e is AccessDenied) lastDenial = e.message;
      await PushService.signOut(scope: SignOutScope.local);
      rethrow;
    }
  }

  static Future<ProfileAccess> requireAdmin() async {
    final account = await profile();
    if (account.role != 'admin') {
      throw const AccessDenied('هذه الشاشة للإدارة فقط / This screen is for administrators only.');
    }
    return account;
  }

  static Future<void> changePassword(String current, String next) async {
    await requireAdmin();
    final email = supabaseClient.auth.currentUser!.email!;
    await signIn(email, current);
    await supabaseClient.auth.updateUser(UserAttributes(password: next));
  }
}
