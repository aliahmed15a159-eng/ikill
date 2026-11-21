import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

/// Supabase owns identity and authorization. Transport receives only an opaque
/// subscription and notification ID, never customer/payment/report content.
class PushService {
  static final clicked = ValueNotifier<String?>(null);
  static String? _app;
  static Future<void> _queue = Future.value();
  static bool get supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  static Future<void> start() async {
    if (!supported) return;
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('push_app');
    if (cached != null) _initialize(cached);
    supabaseClient.auth.onAuthStateChange.listen((_) => sync());
    await sync();
  }
  static void _initialize(String id) {
    if (_app == id) return;
    if (_app != null) return; // Changing brands requires an app restart.
    _app = id;
    OneSignal.initialize(id);
    OneSignal.User.pushSubscription.addObserver((_) => sync());
    OneSignal.Notifications.addClickListener((event) {
      final id = event.notification.additionalData?['notification_id'];
      if (id is String) clicked.value = id;
    });
  }
  static Future<void> sync({bool requestPermission = false}) {
    _queue = _queue.catchError((Object _) {}).then((_) async {
      if (!supported) return;
      final user = supabaseClient.auth.currentUser?.id;
      if (user == null) {
        if (_app != null) await OneSignal.User.pushSubscription.optOut();
        clicked.value = null;
        return;
      }
      final settings = Map<String,dynamic>.from(await supabaseClient.rpc('get_notification_settings') as Map);
      if (settings['push_enabled'] != true || settings['app_id'] == null) {
        if (_app != null) await OneSignal.User.pushSubscription.optOut();
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final app = settings['app_id'] as String;
      await prefs.setString('push_app', app);
      _initialize(app);
      if (_app != app || supabaseClient.auth.currentUser?.id != user) return;
      if (requestPermission) {
        if (!await OneSignal.Notifications.requestPermission(true)) return;
        await OneSignal.User.pushSubscription.optIn();
        await prefs.setBool('push_consent', true);
      } else if (prefs.getBool('push_consent') == true && OneSignal.User.pushSubscription.optedIn != true) {
        await OneSignal.User.pushSubscription.optIn();
      }
      final subscription = OneSignal.User.pushSubscription.id;
      if (subscription == null || supabaseClient.auth.currentUser?.id != user) return;
      var secret = prefs.getString('push_installation_secret');
      if (secret == null) {
        final random = Random.secure();
        secret = List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2,'0')).join();
        await prefs.setString('push_installation_secret',secret);
      }
      await supabaseClient.rpc('register_my_push',params:{'subscription':subscription,'installation_secret':secret});
    }).catchError((Object _) {
      // Transport failure must never prevent login or in-app notifications.
    });
    return _queue;
  }
  static Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    await _queue;
    if (supported && _app != null) {
      // Opt out before logout, even when the network is unavailable.
      await OneSignal.User.pushSubscription.optOut();
      final id = OneSignal.User.pushSubscription.id;
      if (id != null) {
        try { await supabaseClient.rpc('unregister_my_push',params:{'subscription':id}); } catch (_) { /* Generic payload only; next account replaces binding. */ }
      }
    }
    clicked.value = null;
    await supabaseClient.auth.signOut(scope:scope);
  }
}
