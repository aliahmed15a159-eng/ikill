import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

/// Own the two allowlisted mobile callbacks. PKCE exchange is performed by
/// Supabase; never parse/store access tokens or accept arbitrary callback hosts.
class AuthFlow extends ChangeNotifier {
  static final instance=AuthFlow();
  static const callback='net.ikill.app://auth/callback';
  static const recoveryCallback='net.ikill.app://auth/recovery';
  bool recovering=false,handlingLink=false,navigationRequested=false,credentialsBusy=false;
  String? notice;
  void credentialsFinished(){credentialsBusy=false;notifyListeners();}
  String? callbackError;
  String? _lastCode;
  bool _started=false;
  static bool accepts(Uri uri)=>uri.scheme=='net.ikill.app'&&uri.host=='auth'&&(uri.path=='/callback'||uri.path=='/recovery')&&uri.userInfo.isEmpty&&!uri.hasPort;
  Future<void> start() async {
    if(_started)return;_started=true;
    final prefs=await SharedPreferences.getInstance();
    recovering=prefs.getBool('auth_recovery_pending')==true&&supabaseClient.auth.currentSession!=null;
    if(recovering)navigationRequested=true;
    supabaseClient.auth.onAuthStateChange.listen((event){
      if(event.event==AuthChangeEvent.passwordRecovery){recovering=true;navigationRequested=true;unawaited(prefs.setBool('auth_recovery_pending',true));notifyListeners();}
      if(event.event==AuthChangeEvent.signedOut){recovering=false;unawaited(prefs.remove('auth_recovery_pending'));notifyListeners();}
    },onError:(Object _){callbackError='تعذر التحقق من الجلسة. أعد تسجيل الدخول. / Session verification failed. Sign in again.';notifyListeners();});
    final links=AppLinks();
    links.uriLinkStream.listen((uri)=>unawaited(handle(uri)),onError:(Object _){callbackError='تعذر فتح رابط المصادقة. اطلب رابطاً جديداً. / Could not open auth link.';navigationRequested=true;notifyListeners();});
    try{final initial=await links.getInitialLink();if(initial!=null)unawaited(handle(initial));}catch(_){/* No initial mobile callback. */}
  }
  Future<void> handle(Uri uri) async {
    if(!accepts(uri)||handlingLink)return;
    navigationRequested=true;callbackError=null;
    final code=uri.queryParameters['code'];
    if(uri.queryParameters.containsKey('error')||code==null||code.isEmpty||code.length>4096){callbackError='لم تكتمل المصادقة أو انتهت صلاحية الرابط. حاول مجدداً. / Authentication was cancelled or the link expired.';notifyListeners();return;}
    if(_lastCode==code)return;
    _lastCode=code;handlingLink=true;notifyListeners();
    try {
      await supabaseClient.auth.exchangeCodeForSession(code);
      if(uri.path=='/recovery'&&supabaseClient.auth.currentSession!=null){recovering=true;final prefs=await SharedPreferences.getInstance();await prefs.setBool('auth_recovery_pending',true);}
    }catch(_){callbackError='الرابط غير صالح أو انتهت صلاحيته. افتح رابطاً جديداً على الجهاز الذي بدأت منه العملية. / Link invalid or expired. Request a new link on this device.';}
    finally{handlingLink=false;notifyListeners();}
  }
  Future<void> finishRecovery() async {
    recovering=false;
    final prefs=await SharedPreferences.getInstance();await prefs.remove('auth_recovery_pending');
    notifyListeners();
  }
}
