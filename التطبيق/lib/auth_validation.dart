import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

bool validAuthEmail(String input)=>input.trim().length<=254&&RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(input.trim());
int passwordStrength(String input)=>[
  input.length>=8,
  RegExp(r'[A-Za-z\u0600-\u06ff]').hasMatch(input)&&RegExp(r'[0-9]').hasMatch(input),
  RegExp(r'[^A-Za-z0-9\u0600-\u06ff]').hasMatch(input),
  input.length>=12,
].where((v)=>v).length;
bool strongAuthPassword(String input)=>input.length>=8&&input.length<=128&&RegExp(r'[A-Za-z\u0600-\u06ff]').hasMatch(input)&&RegExp(r'[0-9]').hasMatch(input);
String? normalizedWhatsapp(String input) {
  const source='٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹';
  var value=input.split('').map((c){final i=source.indexOf(c);return i<0?c:'${i%10}';}).join().replaceAll(RegExp(r'[\s()-]'),'');
  if(RegExp(r'^01[0125][0-9]{8}$').hasMatch(value))value='+2$value';
  if(value.startsWith('00'))value='+${value.substring(2)}';
  return RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(value)?value:null;
}
String friendlyAuthError(Object error,{bool english=false}) {
  String pick(String ar,String en)=>english?en:ar;
  final code=error is AuthException?error.code:null;
  switch(code){
    case 'invalid_credentials':case 'invalid_login_credentials':
      return pick('البريد الإلكتروني أو كلمة المرور غير صحيحة. يرجى المحاولة مجدداً.','Email or password is incorrect. Please try again.');
    case 'email_not_confirmed':return pick('يرجى تأكيد بريدك الإلكتروني من رسالة التفعيل أولاً.','Please confirm your email first.');
    case 'user_already_exists':case 'email_exists':return pick('يوجد حساب بهذا البريد. جرّب تسجيل الدخول أو استعادة كلمة المرور.','An account already exists. Sign in or reset your password.');
    case 'weak_password':return pick('اختر كلمة مرور أقوى، لا تقل عن ٨ أحرف وتحتوي على حروف وأرقام.','Use a stronger password with at least 8 characters, letters and numbers.');
    case 'same_password':return pick('اختر كلمة مرور مختلفة عن كلمة المرور السابقة.','Choose a different password.');
    case 'over_email_send_rate_limit':case 'over_request_rate_limit':case 'too_many_requests':
      return pick('تمت محاولات كثيرة خلال وقت قصير. انتظر قليلاً ثم حاول مجدداً.','Too many attempts. Please wait and try again.');
    case 'signup_disabled':return pick('إنشاء الحسابات غير متاح حالياً. يرجى التواصل مع الإدارة.','Sign-up is currently unavailable. Contact administration.');
    case 'email_address_invalid':case 'validation_failed':return pick('يرجى التحقق من البريد الإلكتروني والبيانات المدخلة.','Please check your email and entered details.');
    case 'user_banned':return pick('هذا الحساب موقوف حالياً. يرجى التواصل مع الإدارة.','This account is suspended. Contact administration.');
    case 'otp_expired':case 'flow_state_expired':case 'flow_state_not_found':case 'bad_code_verifier':case 'bad_oauth_state':
      return pick('انتهت صلاحية الرابط أو فُتح على جهاز آخر. اطلب رابطاً جديداً وافتحه على هذا الجهاز.','Link expired or opened on another device. Request a new link on this device.');
    case 'session_not_found':case 'refresh_token_not_found':case 'refresh_token_already_used':
      return pick('انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.','Your session expired. Please sign in again.');
    case 'provider_disabled':case 'oauth_provider_not_supported':case 'email_provider_disabled':
      return pick('طريقة الدخول هذه غير متاحة حالياً. جرّب طريقة أخرى أو تواصل مع الإدارة.','This sign-in method is unavailable. Try another method or contact administration.');
    case 'access_denied':return pick('لم تكتمل الموافقة على الدخول. يمكنك المحاولة مجدداً.','Sign-in consent was not completed. Please try again.');
  }
  if(error is SocketException||error is TimeoutException||error.toString().contains('Failed host lookup'))return pick('تعذر الاتصال. تحقق من الإنترنت ثم حاول مجدداً.','Connection failed. Check your internet and try again.');
  if(error is AuthException&&error.statusCode=='429')return pick('يرجى الانتظار قليلاً قبل إعادة المحاولة.','Please wait before trying again.');
  // Never echo provider/database errors, callback URLs, tokens or stack traces.
  return pick('تعذرت العملية الآن. تحقق من البيانات والاتصال ثم حاول مجدداً.','Unable to complete the operation. Check your details and connection, then retry.');
}
