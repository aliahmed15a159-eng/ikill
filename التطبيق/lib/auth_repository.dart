import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_flow.dart';
import 'auth_service.dart';
import 'backend.dart';
import 'supabase_client.dart';

abstract class AuthGateway {
  bool get ready;
  Future<void> login(String email,String password);
  Future<bool> register(String name,String phone,String email,String password);
  Future<void> google();
  Future<void> reset(String email);
}
class SupabaseAuthGateway implements AuthGateway {
  const SupabaseAuthGateway();
  @override
  bool get ready=>Backend.ready;
  @override
  Future<void> login(String email,String password) async {await AuthService.signIn(email,password);}
  @override
  Future<bool> register(String name,String phone,String email,String password) async {
    final response=await supabaseClient.auth.signUp(email:email,password:password,emailRedirectTo:AuthFlow.callback,data:{'full_name':name});
    if(response.session==null)return false;
    final profile=await AuthService.profile();
    if(profile.role=='customer')await supabaseClient.rpc('complete_customer_profile',params:{'display_name':name,'whatsapp_phone':phone});
    return true;
  }
  @override
  Future<void> google() async {
    final opened=await supabaseClient.auth.signInWithOAuth(OAuthProvider.google,redirectTo:AuthFlow.callback,authScreenLaunchMode:LaunchMode.externalApplication,queryParams:{'prompt':'select_account'});
    if(!opened)throw const AuthException('Could not open sign-in browser');
  }
  @override
  Future<void> reset(String email)=>supabaseClient.auth.resetPasswordForEmail(email,redirectTo:AuthFlow.recoveryCallback);
}
class AuthBrand {
  final String name;
  final String? logoUrl;
  final int color;
  const AuthBrand({this.name='iKILL',this.logoUrl,this.color=0xff15803d});
  static Future<AuthBrand> load() async {
    if(!Backend.ready)return const AuthBrand();
    try {
      final raw=await supabaseClient.rpc('get_auth_brand',params:{'brand_slug':SupabaseConnection.brandSlug});
      final row=Map<String,dynamic>.from(raw as Map);
      String? logo;
      if(row['logo_path'] is String){try{logo=await supabaseClient.storage.from('brand-assets').createSignedUrl(row['logo_path'] as String,3600);}catch(_){/* Published logo may not be uploaded yet. */}}
      return AuthBrand(name:row['company_name'] as String? ?? 'iKILL',logoUrl:logo,color:int.tryParse('ff${row['primary_hex']}',radix:16)??0xff15803d);
    }catch(_){return const AuthBrand();}
  }
}
