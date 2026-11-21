import 'package:supabase_flutter/supabase_flutter.dart';
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
