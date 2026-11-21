import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_flow.dart';
import 'auth_repository.dart';
import 'auth_service.dart';
import 'auth_validation.dart';
import 'push_service.dart';
import 'supabase_client.dart';

// Google's unmodified multi-colour G mark; OAuth credentials stay in Supabase.
const googleMark='''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/><path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6C44.4 38.03 46.98 31.87 46.98 24.55z"/><path fill="#FBBC05" d="M10.53 28.59A14.41 14.41 0 0 1 9.75 24c0-1.59.27-3.13.76-4.59l-7.98-6.19A23.87 23.87 0 0 0 0 24c0 3.87.93 7.53 2.56 10.78l7.97-6.19z"/><path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.91-5.8l-7.73-6c-2.15 1.45-4.92 2.3-8.18 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/></svg>''';

class AuthFrame extends StatefulWidget {
  final String title,subtitle;
  final Widget child;
  final bool english;
  const AuthFrame({super.key,required this.title,required this.subtitle,required this.child,this.english=false});
  @override
  State<AuthFrame> createState()=>_AuthFrameState();
}
class _AuthFrameState extends State<AuthFrame> {
  late final brand=AuthBrand.load();
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(backgroundColor:Colors.transparent,elevation:0),
    body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:520),child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(24,4,24,32),child:FutureBuilder<AuthBrand>(future:brand,builder:(context,snapshot){
      final config=snapshot.data??const AuthBrand();
      final color=Color(config.color);
      final fallback=Image.asset('assets/images/ikill-logo-transparent.png',height:64,fit:BoxFit.contain);
      return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:LinearGradient(colors:[color,color.withValues(alpha:.75)]),borderRadius:BorderRadius.circular(28)),child:Column(children:[
          Container(padding:const EdgeInsets.symmetric(horizontal:20,vertical:12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20)),child:config.logoUrl==null?fallback:Image.network(config.logoUrl!,height:64,fit:BoxFit.contain,errorBuilder:(_,error,stack)=>fallback)),
          const SizedBox(height:12),Text(config.name,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w800)),
          const SizedBox(height:6),Text(widget.english?'Professional care. One secure account.':'رعاية احترافية تبدأ بحساب آمن',textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:14)),
        ])),
        const SizedBox(height:26),Text(widget.title,style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),
        const SizedBox(height:8),Text(widget.subtitle,style:Theme.of(context).textTheme.bodyMedium?.copyWith(color:Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height:24),AnimatedSize(duration:const Duration(milliseconds:260),curve:Curves.easeInOut,alignment:Alignment.topCenter,child:widget.child),
        const SizedBox(height:24),Row(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.lock_outline,size:16),const SizedBox(width:6),Flexible(child:Text(widget.english?'Your account is secured by Supabase':'بيانات حسابك محمية عبر Supabase',textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodySmall))]),
      ]);
    }))))),
  );
}
class AuthPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled,newPassword,english;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  const AuthPasswordField({super.key,required this.controller,required this.label,this.enabled=true,this.newPassword=false,this.english=false,this.validator,this.onChanged});
  @override
  State<AuthPasswordField> createState()=>_AuthPasswordFieldState();
}
class _AuthPasswordFieldState extends State<AuthPasswordField>{
  bool hidden=true;
  @override
  Widget build(BuildContext context)=>TextFormField(controller:widget.controller,enabled:widget.enabled,obscureText:hidden,enableSuggestions:false,autocorrect:false,autofillHints:[widget.newPassword?AutofillHints.newPassword:AutofillHints.password],autovalidateMode:AutovalidateMode.onUserInteraction,validator:widget.validator,onChanged:widget.onChanged,decoration:InputDecoration(labelText:widget.label,prefixIcon:const Icon(Icons.lock_outline),suffixIcon:IconButton(tooltip:widget.english?(hidden?'Show password':'Hide password'):(hidden?'إظهار كلمة المرور':'إخفاء كلمة المرور'),onPressed:()=>setState(()=>hidden=!hidden),icon:Icon(hidden?Icons.visibility_outlined:Icons.visibility_off_outlined))));
}
class PasswordMeter extends StatelessWidget {
  final String password;
  final bool english;
  const PasswordMeter({super.key,required this.password,required this.english});
  @override
  Widget build(BuildContext context){final score=passwordStrength(password);return Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[LinearProgressIndicator(value:score/4,borderRadius:BorderRadius.circular(8),minHeight:5),const SizedBox(height:5),Text(english?'8+ characters with letters and numbers • Strength $score/4':'٨ أحرف على الأقل، مع حروف وأرقام • القوة $score/٤',style:Theme.of(context).textTheme.bodySmall)]));}
}

class AuthScreen extends StatefulWidget {
  final bool english;
  final AuthGateway gateway;
  final VoidCallback? onComplete;
  const AuthScreen({super.key,this.english=false,this.gateway=const SupabaseAuthGateway(),this.onComplete});
  @override
  State<AuthScreen> createState()=>_AuthScreenState();
}
class _AuthScreenState extends State<AuthScreen>{
  final email=TextEditingController(),password=TextEditingController(),confirmation=TextEditingController(),name=TextEditingController(),phone=TextEditingController();
  final form=GlobalKey<FormState>();
  bool signup=false,forgot=false,busy=false,resetCoolingDown=false;
  String? error,notice;
  Timer? cooldown;
  String tr(String ar,String en)=>widget.english?en:ar;
  @override
  void dispose(){for(final c in [email,password,confirmation,name,phone]){c.dispose();}cooldown?.cancel();super.dispose();}
  Future<void> run(Future<void> Function() operation) async {
    if(busy)return;FocusScope.of(context).unfocus();
    setState((){busy=true;error=null;notice=null;});
    AuthFlow.instance.credentialsBusy=true;
    try{await operation();}catch(e){if(mounted)setState(()=>error=e is AccessDenied?e.message:friendlyAuthError(e,english:widget.english));}
    finally{if(mounted)setState(()=>busy=false);AuthFlow.instance.credentialsFinished();}
  }
  Future<void> submit() async {
    if(!(form.currentState?.validate()??false))return;
    await run(() async {
      if(forgot){
        await widget.gateway.reset(email.text.trim());
        if(mounted){setState((){notice=tr('إذا كان البريد مسجلاً، ستصلك رسالة الاستعادة. افتح الرابط على هذا الجهاز.','If this email is registered, a reset link will arrive. Open it on this device.');resetCoolingDown=true;});cooldown=Timer(const Duration(seconds:60),(){if(mounted)setState(()=>resetCoolingDown=false);});}
      }else if(signup){
        final immediate=await widget.gateway.register(name.text.trim(),normalizedWhatsapp(phone.text)!,email.text.trim(),password.text);
        if(immediate){widget.onComplete?.call();}else if(mounted){setState(()=>notice=tr('تم استلام طلب إنشاء الحساب. إذا طُلب تأكيد البريد، افتح رسالة التفعيل على هذا الجهاز ثم سجّل الدخول.','Sign-up received. If email confirmation is required, open the confirmation link on this device and sign in.'));}
      }else {await widget.gateway.login(email.text.trim(),password.text);widget.onComplete?.call();}
    });
  }
  @override
  Widget build(BuildContext context){final enabled=!busy&&widget.gateway.ready;return AuthFrame(english:widget.english,title:forgot?tr('نسيت كلمة المرور؟','Forgot password?'):signup?tr('أنشئ حسابك الجديد','Create your account'):tr('أهلاً بعودتك','Welcome back'),subtitle:forgot?tr('سنساعدك على العودة إلى حسابك بأمان.','Let’s help you securely recover your account.'):tr('اطلب خدمتك وتابع حسابك بسهولة من مكان واحد.','Request a service and access your account in one place.'),child:AutofillGroup(child:Form(key:form,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    if(!widget.gateway.ready)Text(tr('يلزم إعداد Supabase والاتصال بالإنترنت للمصادقة.','Supabase configuration and internet are required.')),
    if(!forgot)...[
      SegmentedButton<bool>(segments:[ButtonSegment(value:false,label:Text(tr('تسجيل الدخول','Sign in'))),ButtonSegment(value:true,label:Text(tr('حساب جديد','Sign up')))],selected:{signup},onSelectionChanged:enabled?(v)=>setState((){signup=v.first;error=null;notice=null;password.clear();confirmation.clear();}):null),
      const SizedBox(height:20),
      OutlinedButton.icon(style:OutlinedButton.styleFrom(backgroundColor:Colors.white,foregroundColor:const Color(0xff1f1f1f),side:const BorderSide(color:Color(0xff747775)),minimumSize:const Size.fromHeight(50)),onPressed:enabled?()=>run(() async {await widget.gateway.google();if(mounted)setState(()=>notice=tr('أكمل الدخول في المتصفح ثم عد إلى التطبيق.','Complete sign-in in your browser, then return to the app.'));}):null,icon:SvgPicture.string(googleMark,width:20,height:20),label:Text(tr('المتابعة باستخدام Google','Continue with Google'))),
      Padding(padding:const EdgeInsets.symmetric(vertical:18),child:Row(children:[const Expanded(child:Divider()),Padding(padding:const EdgeInsets.symmetric(horizontal:14),child:Text(tr('أو بالبريد الإلكتروني','or with email'))),const Expanded(child:Divider())])),
    ],
    if(signup&&!forgot)...[
      TextFormField(controller:name,enabled:enabled,autofillHints:const [AutofillHints.name],textInputAction:TextInputAction.next,autovalidateMode:AutovalidateMode.onUserInteraction,decoration:InputDecoration(labelText:tr('الاسم الكامل','Full name'),prefixIcon:const Icon(Icons.person_outline)),validator:(v)=>(v??'').trim().length<2||(v??'').trim().length>100?tr('أدخل اسمك من حرفين إلى ١٠٠ حرف.','Enter a name between 2 and 100 characters.'):null),
      const SizedBox(height:14),TextFormField(controller:phone,enabled:enabled,keyboardType:TextInputType.phone,autofillHints:const [AutofillHints.telephoneNumber],autovalidateMode:AutovalidateMode.onUserInteraction,decoration:InputDecoration(labelText:tr('رقم الموبايل (واتساب)','Mobile / WhatsApp'),hintText:'010… / +20…',prefixIcon:const Icon(Icons.phone_outlined)),validator:(v)=>normalizedWhatsapp(v??'')==null?tr('أدخل رقم موبايل مصرياً صحيحاً أو رقماً دولياً يبدأ بـ +.','Enter a valid Egyptian mobile or international + number.'):null),const SizedBox(height:14),
    ],
    TextFormField(controller:email,enabled:enabled,keyboardType:TextInputType.emailAddress,textInputAction:TextInputAction.next,autofillHints:const [AutofillHints.email],autovalidateMode:AutovalidateMode.onUserInteraction,decoration:InputDecoration(labelText:tr('البريد الإلكتروني','Email'),prefixIcon:const Icon(Icons.alternate_email)),validator:(v)=>validAuthEmail(v??'')?null:tr('أدخل بريداً إلكترونياً صحيحاً.','Enter a valid email address.')),
    if(!forgot)...[
      const SizedBox(height:14),AuthPasswordField(controller:password,label:tr('كلمة المرور','Password'),english:widget.english,enabled:enabled,newPassword:signup,onChanged:(_)=>setState((){}),validator:(v)=>signup?(strongAuthPassword(v??'')?null:tr('استخدم ٨ أحرف على الأقل مع حروف وأرقام.','Use 8+ characters, letters and numbers.')):((v??'').isEmpty?tr('أدخل كلمة المرور.','Enter your password.'):null)),
      if(signup)...[PasswordMeter(password:password.text,english:widget.english),AuthPasswordField(controller:confirmation,label:tr('تأكيد كلمة المرور','Confirm password'),english:widget.english,enabled:enabled,newPassword:true,validator:(v)=>(v??'').isNotEmpty&&v==password.text?null:tr('كلمتا المرور غير متطابقتين.','Passwords do not match.'))],
      if(!signup)Align(alignment:AlignmentDirectional.centerEnd,child:TextButton(onPressed:enabled?()=>setState((){forgot=true;error=null;notice=null;}):null,child:Text(tr('نسيت كلمة المرور؟','Forgot password?')))),
    ],
    if(error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(error!,semanticsLabel:error,style:TextStyle(color:Theme.of(context).colorScheme.error))),
    if(AuthFlow.instance.callbackError!=null)Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text(AuthFlow.instance.callbackError!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
    if(notice!=null||AuthFlow.instance.notice!=null)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(notice??AuthFlow.instance.notice!,style:TextStyle(color:Theme.of(context).colorScheme.primary))),
    const SizedBox(height:16),FilledButton(onPressed:enabled&&!(forgot&&resetCoolingDown)?submit:null,child:busy?const SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2)):Text(forgot?tr('إرسال رابط الاستعادة','Send reset link'):signup?tr('إنشاء الحساب','Create account'):tr('دخول آمن','Sign in securely'))),
    if(forgot)TextButton(onPressed:busy?null:()=>setState((){forgot=false;error=null;notice=null;}),child:Text(tr('العودة لتسجيل الدخول','Back to sign in'))),
    if(!forgot)Padding(padding:const EdgeInsets.only(top:16),child:Text(tr('تُنشأ الحسابات الجديدة كعملاء خدمات فقط. صلاحيات الإدارة والفنيين والبوابة التعاقدية تُمنح بواسطة الإدارة.','New accounts are service customers only. Staff and contract portal permissions are granted by administration.'),textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodySmall)),
  ]))));}
}

class CompleteProfileScreen extends StatefulWidget {
  final ProfileAccess profile;
  final bool english;
  final VoidCallback onComplete;
  final Future<void> Function(String)? save;
  const CompleteProfileScreen({super.key,required this.profile,required this.onComplete,this.english=false,this.save});
  @override
  State<CompleteProfileScreen> createState()=>_CompleteProfileScreenState();
}
class _CompleteProfileScreenState extends State<CompleteProfileScreen>{
  final phone=TextEditingController();final form=GlobalKey<FormState>();bool busy=false;String? error;
  String tr(String ar,String en)=>widget.english?en:ar;
  @override
  void dispose(){phone.dispose();super.dispose();}
  Future<void> save() async {
    if(!(form.currentState?.validate()??false)||busy)return;setState((){busy=true;error=null;});
    try {
      final normalized=normalizedWhatsapp(phone.text)!;
      if(widget.save!=null){await widget.save!(normalized);}else{await supabaseClient.rpc('complete_customer_profile',params:{'display_name':widget.profile.fullName.trim().length<2?'عميل جديد':widget.profile.fullName,'whatsapp_phone':normalized});}
      widget.onComplete();
    }catch(e){if(mounted)setState(()=>error=friendlyAuthError(e,english:widget.english));}finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context)=>PopScope(canPop:false,child:AuthFrame(english:widget.english,title:tr('خطوة صغيرة ونبدأ','One last step'),subtitle:tr('أهلاً ${widget.profile.fullName}، أضف رقم واتساب للتواصل الميداني وتنسيق الزيارات. ستظهر هذه الخطوة مرة واحدة.','Welcome ${widget.profile.fullName}. Add your WhatsApp number for field coordination. This step appears once.'),child:Form(key:form,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    TextFormField(controller:phone,enabled:!busy,keyboardType:TextInputType.phone,autofillHints:const [AutofillHints.telephoneNumber],autovalidateMode:AutovalidateMode.onUserInteraction,decoration:InputDecoration(labelText:tr('رقم الموبايل (واتساب)','Mobile / WhatsApp'),prefixIcon:const Icon(Icons.phone_outlined),hintText:'010… / +20…'),validator:(v)=>normalizedWhatsapp(v??'')==null?tr('أدخل رقماً مصرياً صحيحاً أو رقماً دولياً يبدأ بـ +.','Enter a valid Egyptian mobile or international + number.'):null),
    if(error!=null)Padding(padding:const EdgeInsets.all(12),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),const SizedBox(height:20),FilledButton(onPressed:busy?null:save,child:Text(busy?'…':tr('حفظ ومتابعة','Save and continue'))),TextButton(onPressed:busy?null:()=>PushService.signOut(),child:Text(tr('تسجيل الخروج','Sign out'))),
  ]))));
}
class ResetPasswordScreen extends StatefulWidget {
  final bool english;
  const ResetPasswordScreen({super.key,this.english=false});
  @override
  State<ResetPasswordScreen> createState()=>_ResetPasswordScreenState();
}
class _ResetPasswordScreenState extends State<ResetPasswordScreen>{
  final password=TextEditingController(),confirmation=TextEditingController();final form=GlobalKey<FormState>();bool busy=false;String? error;
  String tr(String ar,String en)=>widget.english?en:ar;
  @override
  void dispose(){password.dispose();confirmation.dispose();super.dispose();}
  Future<void> update() async {
    if(!(form.currentState?.validate()??false)||busy)return;setState((){busy=true;error=null;});
    try{await supabaseClient.auth.updateUser(UserAttributes(password:password.text));AuthFlow.instance.notice=tr('تم تحديث كلمة المرور. سجّل الدخول بكلمة المرور الجديدة.','Password updated. Sign in with your new password.');await PushService.signOut();await AuthFlow.instance.finishRecovery();}
    catch(e){if(mounted)setState(()=>error=friendlyAuthError(e,english:widget.english));}finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context)=>PopScope(canPop:false,child:AuthFrame(english:widget.english,title:tr('كلمة مرور جديدة','Set a new password'),subtitle:tr('اختر كلمة مرور قوية لحماية حسابك.','Choose a strong password to protect your account.'),child:Form(key:form,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    AuthPasswordField(controller:password,label:tr('كلمة المرور الجديدة','New password'),newPassword:true,english:widget.english,enabled:!busy,onChanged:(_)=>setState((){}),validator:(v)=>strongAuthPassword(v??'')?null:tr('استخدم ٨ أحرف على الأقل مع حروف وأرقام.','Use 8+ characters with letters and numbers.')),
    PasswordMeter(password:password.text,english:widget.english),AuthPasswordField(controller:confirmation,label:tr('تأكيد كلمة المرور','Confirm password'),newPassword:true,english:widget.english,enabled:!busy,validator:(v)=>(v??'').isNotEmpty&&v==password.text?null:tr('كلمتا المرور غير متطابقتين.','Passwords do not match.')),
    if(error!=null)Padding(padding:const EdgeInsets.all(12),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),const SizedBox(height:20),FilledButton(onPressed:busy?null:update,child:Text(busy?'…':tr('حفظ كلمة المرور','Save password'))),TextButton(onPressed:busy?null:()=>PushService.signOut(),child:Text(tr('إلغاء وتسجيل الخروج','Cancel and sign out'))),
  ]))));
}
