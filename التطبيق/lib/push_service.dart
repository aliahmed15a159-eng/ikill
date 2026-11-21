import 'dart:async';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

/// Background delivery never initializes a second identity/database backend or
/// opens UI. Android/iOS display the notification; taps are handled on the UI isolate.
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  try { await Firebase.initializeApp(); } catch (_) { /* Missing native configuration. */ }
}

class PushState {
  final bool configured,permission,registered,enabled;
  final String message;
  const PushState(this.message,{this.configured=false,this.permission=false,this.registered=false,this.enabled=false});
}
class PushService {
  static final clicked=ValueNotifier<String?>(null);
  static final foreground=ValueNotifier<RemoteMessage?>(null);
  static final status=ValueNotifier<PushState>(const PushState('جارٍ فحص إعدادات FCM / Checking FCM configuration'));
  static bool _initialized=false,_started=false,_loggingOut=false;
  static int _epoch=0;
  static String? _token,_registeredToken;
  static Future<void> _queue=Future.value();
  static bool get supported=>!kIsWeb&&(defaultTargetPlatform==TargetPlatform.android||defaultTargetPlatform==TargetPlatform.iOS);
  static bool get configured=>_initialized;
  static String? notificationId(Map<String,dynamic> data) {
    final id=data['notification_id'];
    return id is String&&RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(id)?id:null;
  }
  static void _tap(RemoteMessage message) {
    final id=notificationId(message.data);
    if(id!=null)clicked.value=id;
    // type/reference_id/reference_kind are carried too, but navigation reloads
    // the canonical Supabase notification under current recipient RLS.
  }
  static Future<void> start() async {
    if(_started)return;
    _started=true;
    if(!supported){status.value=const PushState('FCM متاح على Android وiOS فقط / Mobile only');return;}
    try {
      await Firebase.initializeApp();
      _initialized=true;
      FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert:false,badge:false,sound:false);
      FirebaseMessaging.onMessage.listen((message) {if(supabaseClient.auth.currentSession!=null)foreground.value=message;});
      FirebaseMessaging.onMessageOpenedApp.listen(_tap);
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {_token=token;unawaited(sync(refreshedToken:token));},onError:(Object _) {status.value=const PushState('تعذر تحديث رمز الجهاز / Token refresh failed',configured:true);});
      supabaseClient.auth.onAuthStateChange.listen((event) {
        if(event.event==AuthChangeEvent.signedOut) {if(!_loggingOut&&supabaseClient.auth.currentSession==null)unawaited(_localLogout());}
        else {unawaited(sync(requestPermission:event.event==AuthChangeEvent.signedIn));}
      });
      final initial=await FirebaseMessaging.instance.getInitialMessage();
      if(initial!=null)_tap(initial);
      await sync(requestPermission:true);
    } catch (_) {
      status.value=PushState(_initialized?'FCM مهيأ، لكن تعذر الاتصال أو تسجيل الجهاز / Configured; connection or registration failed':'إعداد Firebase غير موجود أو غير صالح لهذه المنصة / Native Firebase config missing or invalid',configured:_initialized);
      // A missing iOS plist must not stop Supabase or the app from launching.
    }
  }
  static Future<void> sync({bool requestPermission=false,String? refreshedToken}) {
    final epoch=_epoch;
    _queue=_queue.catchError((Object _) {}).then((_) async {
      if(!_initialized||_loggingOut||epoch!=_epoch)return;
      final user=supabaseClient.auth.currentUser?.id;
      if(user==null){status.value=const PushState('إعداد FCM موجود — سجّل الدخول / Configured; sign in',configured:true);return;}
      final settings=Map<String,dynamic>.from(await supabaseClient.rpc('get_notification_settings') as Map);
      if(settings['project_id']!=Firebase.app().options.projectId){status.value=const PushState('مشروع FCM لا يطابق إعداد الخادم / Project mismatch',configured:true);return;}
      var permission=await FirebaseMessaging.instance.getNotificationSettings();
      if(requestPermission&&permission.authorizationStatus!=AuthorizationStatus.authorized&&permission.authorizationStatus!=AuthorizationStatus.provisional){permission=await FirebaseMessaging.instance.requestPermission(alert:true,badge:true,sound:true);}
      final allowed=permission.authorizationStatus==AuthorizationStatus.authorized||permission.authorizationStatus==AuthorizationStatus.provisional;
      final enabled=settings['push_enabled']==true;
      if(!allowed){
        if(supabaseClient.auth.currentUser?.id==user)await supabaseClient.rpc('unregister_my_fcm',params:{'device_token':_registeredToken??_token});
        status.value=PushState('إعداد FCM موجود؛ صلاحية الإشعارات غير مفعّلة. فعّلها من إعدادات الهاتف / Permission disabled',configured:true,enabled:enabled);return;
      }
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      // iOS getToken requires an APNs token; do not claim readiness before it exists.
      if(defaultTargetPlatform==TargetPlatform.iOS&&await FirebaseMessaging.instance.getAPNSToken()==null){status.value=PushState('بانتظار APNs: راجع توقيع iOS وإعداد Apple / Waiting for APNs',configured:true,permission:true,enabled:enabled);return;}
      final token=refreshedToken??await FirebaseMessaging.instance.getToken();
      if(token==null)throw StateError('TOKEN_UNAVAILABLE');
      if(_loggingOut||epoch!=_epoch||supabaseClient.auth.currentUser?.id!=user)return;
      final prefs=await SharedPreferences.getInstance();
      var secret=prefs.getString('fcm_installation_secret');
      if(secret==null){final random=Random.secure();secret=List.generate(32,(_)=>random.nextInt(256).toRadixString(16).padLeft(2,'0')).join();await prefs.setString('fcm_installation_secret',secret);}
      if(_loggingOut||epoch!=_epoch||supabaseClient.auth.currentUser?.id!=user)return;
      await supabaseClient.rpc('register_my_fcm',params:{'device_token':token,'installation_secret':secret});
      _token=token;_registeredToken=token;
      status.value=PushState(enabled?'FCM: الإعداد والصلاحية ورمز الجهاز جاهزون؛ راجع حالة الخادم / Device ready; check server status':'FCM: الجهاز مسجل؛ الإرسال معطّل في إعدادات الإدارة / Registered; server sending disabled',configured:true,permission:true,registered:true,enabled:enabled);
    }).catchError((Object _) {status.value=PushState('إعداد FCM موجود؛ تعذر تسجيل الجهاز في Supabase. أعد المحاولة / Registration failed; retry',configured:_initialized);});
    return _queue;
  }
  static Future<void> _localLogout() async {
    _epoch++;
    clicked.value=null;foreground.value=null;_token=null;_registeredToken=null;
    if(_initialized){
      try {await FirebaseMessaging.instance.setAutoInitEnabled(false);await FirebaseMessaging.instance.deleteToken().timeout(const Duration(seconds:8));}catch(_){/* Offline deletion is best-effort; push payloads contain no private content. */}
    }
    status.value=PushState('تم تسجيل الخروج؛ إشعارات الجهاز متوقفة / Signed out',configured:_initialized);
  }
  static Future<void> signOut({SignOutScope scope=SignOutScope.local}) async {
    _loggingOut=true;_epoch++;
    try {
      try {await _queue.timeout(const Duration(seconds:10));}catch(_){/* Never indefinitely delay logout. */}
      if(supabaseClient.auth.currentUser!=null){
        try {await supabaseClient.rpc('unregister_my_fcm',params:{'device_token':_registeredToken??_token}).timeout(const Duration(seconds:10));}catch(_){/* Offline server cleanup cannot be guaranteed; current RLS still guards all references. */}
      }
      await _localLogout();
      await supabaseClient.auth.signOut(scope:scope);
    }finally{_loggingOut=false;}
  }
}
