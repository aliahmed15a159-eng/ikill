import 'design/components.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin.dart' show AdminDashboard;
import 'auth_flow.dart';
import 'auth_screens.dart';
import 'auth_service.dart';
import 'auth_validation.dart';
import 'backend.dart';
import 'content.dart';
import 'documents_screen.dart';
import 'main.dart' show LegalPage;
import 'notifications_screen.dart';
import 'push_service.dart';
import 'request_form.dart';
import 'supabase_client.dart';
import 'technician_tasks.dart' show TechnicianTasks, fieldAccess;

class AccountPage extends StatefulWidget {
  final bool english;
  const AccountPage({super.key,this.english=false});
  static final _contexts=<BuildContext>{};
  static bool get visible=>_contexts.any((context)=>context.mounted&&ModalRoute.of(context)?.isCurrent==true);
  @override
  State<AccountPage> createState()=>_AccountPageState();
}
class _AccountPageState extends State<AccountPage>{
  StreamSubscription<AuthState>? subscription;
  Future<ProfileAccess>? data;
  @override
  void initState(){super.initState();AccountPage._contexts.add(context);AuthFlow.instance.addListener(changed);if(Backend.ready){subscription=supabaseClient.auth.onAuthStateChange.listen((_)=>changed(),onError:(Object _)=>changed());}reload();}
  void reload(){data=Backend.ready&&supabaseClient.auth.currentSession!=null?fieldAccess():null;}
  void changed(){if(mounted)setState(reload);}
  @override
  void dispose(){AccountPage._contexts.remove(context);AuthFlow.instance.removeListener(changed);subscription?.cancel();super.dispose();}
  @override
  Widget build(BuildContext context){
    final flow=AuthFlow.instance;
    if(flow.handlingLink)return const Scaffold(body:SkeletonLoader());
    if(flow.recovering)return ResetPasswordScreen(english:widget.english);
    if(flow.credentialsBusy||!Backend.ready||supabaseClient.auth.currentSession==null)return AuthScreen(english:widget.english,onComplete:changed);
    return FutureBuilder<ProfileAccess>(future:data,builder:(context,snapshot){
      if(snapshot.hasError)return AuthFrame(english:widget.english,title:widget.english?'Account access':'صلاحية الحساب',subtitle:snapshot.error is AccessDenied?snapshot.error.toString():friendlyAuthError(snapshot.error!,english:widget.english),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[OutlinedButton(onPressed:changed,child:Text(widget.english?'Retry':'إعادة المحاولة')),FilledButton(onPressed:()=>PushService.signOut(),child:Text(widget.english?'Sign out':'تسجيل الخروج'))]));
      if(!snapshot.hasData)return const Scaffold(body:SkeletonLoader());
      final profile=snapshot.data!;
      if(profile.incomplete)return CompleteProfileScreen(profile:profile,english:widget.english,onComplete:changed);
      switch(profile.role){
        case 'admin':return AdminDashboard(english:widget.english);
        case 'technician':return TechnicianTasks(english:widget.english,tenant:profile.tenantId);
        case 'client':return Scaffold(appBar:AppBar(title:Text(widget.english?'My contract portal':'بوابتي التعاقدية'),actions:[const NotificationBell(),IconButton(tooltip:widget.english?'Sign out':'خروج',onPressed:()=>PushService.signOut(),icon:const Icon(Icons.logout))]),body:DocumentsScreen(english:widget.english,portal:true));
        case 'customer':return CustomerHome(profile:profile,english:widget.english);
        default:return const Scaffold(body:Center(child:Text('الحساب غير مصرح له / Account not authorized')));
      }
    });
  }
}
class CustomerHome extends StatefulWidget {
  final ProfileAccess profile;
  final bool english;
  const CustomerHome({super.key,required this.profile,required this.english});
  @override
  State<CustomerHome> createState()=>_CustomerHomeState();
}
class _CustomerHomeState extends State<CustomerHome>{
  late final content=SiteContent.load();
  String tr(String ar,String en)=>widget.english?en:ar;
  Future<void> request(String kind) async {
    try {
      final loaded=await content;
      if(!mounted)return;
      await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>Scaffold(appBar:AppBar(title:Text(kind=='contract'?tr('طلب معاينة منشأة','Request a site survey'):tr('طلب خدمة لمرة واحدة','Request a one-off service'))),body:SingleChildScrollView(padding:const EdgeInsets.all(20),child:RequestForm(english:widget.english,content:loaded,initialKind:kind,initialContact:{'name':widget.profile.fullName,'phone':widget.profile.data['phone'] as String? ?? '','email':supabaseClient.auth.currentUser?.email??''},onPrivacy:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LegalPage(content:loaded,english:widget.english))))))));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(friendlyAuthError(e,english:widget.english))));}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(tr('حسابي','My account')),actions:[const NotificationBell(),IconButton(tooltip:tr('خروج','Sign out'),onPressed:()=>PushService.signOut(),icon:const Icon(Icons.logout))]),body:ListView(padding:const EdgeInsets.all(24),children:[
    Text(tr('أهلاً ${widget.profile.fullName}','Welcome ${widget.profile.fullName}'),style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:10),Text(tr('كيف نقدر نساعدك اليوم؟','How can we help you today?')),const SizedBox(height:24),
    for(final entry in [(Icons.home_work_outlined,tr('خدمة لمرة واحدة','One-off service'),tr('مكافحة آفات سكنية بسعر معتمد ودفع إنستا باي بمراجعة يدوية.','Residential pest control with an approved quote and manually reviewed InstaPay payment.'),'residential'),(Icons.business_outlined,tr('معاينة منشأة','Business site survey'),tr('ابدأ بطلب معاينة لتحديد احتياجات منشأتك.','Request a survey to assess your business needs.'),'contract')])Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(entry.$1,size:36,color:Theme.of(context).colorScheme.primary),const SizedBox(height:12),Text(entry.$2,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),Text(entry.$3),const SizedBox(height:14),FilledButton.icon(onPressed:()=>request(entry.$4),icon:const Icon(Icons.arrow_forward),label:Text(tr('ابدأ الطلب','Start request')))]))),
    const SizedBox(height:20),ListTile(leading:const Icon(Icons.phone_outlined),title:Text(widget.profile.data['phone'] as String? ?? ''),subtitle:Text(tr('رقم التواصل الميداني — إدخال الرقم لا يثبت ملكيته على واتساب.','Field contact number; entry alone does not verify WhatsApp ownership.'))),Text(tr('هذا حساب عميل خدمات. البوابة التعاقدية تُفعّل بواسطة الإدارة فقط.','This is a service customer account. Contract portal access is granted only by administration.'),style:Theme.of(context).textTheme.bodySmall),
  ]));
}
