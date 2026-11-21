import 'request_admin.dart';
import 'notification_settings.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import 'instapay_service.dart';
import 'push_service.dart';
import 'request_models.dart';
import 'supabase_client.dart';
import 'technician_tasks.dart';

String notificationTable(String kind) => switch(kind) {
  'visit' => 'visits', 'survey' => 'surveys', 'invoice' => 'invoices', 'report' => 'visit_reports',
  _ => throw const FormatException('Unknown reference'),
};
Future<void> openNotification(BuildContext context, String id) async {
  try {
    await AuthService.profile();
    final row = await supabaseClient.from('notifications').select().eq('id',id).single();
    await supabaseClient.rpc('mark_notifications_read',params:{'target':id});
    if (context.mounted) await Navigator.push(context,MaterialPageRoute<void>(builder:(_) => NotificationReference(kind:row['reference_kind'] as String,id:row['reference_id'] as String)));
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الإشعار أو المرجع غير متاح لهذا الحساب / Reference unavailable for this account')));
  }
}

class NotificationNavigation {
  static bool opening=false;
  static void handle(BuildContext context) {
    final id=PushService.clicked.value;
    if(id==null||opening||supabaseClient.auth.currentSession==null)return;
    opening=true;
    PushService.clicked.value=null;
    openNotification(context,id).whenComplete(()=>opening=false);
  }
}

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}
class _NotificationBellState extends State<NotificationBell> with WidgetsBindingObserver {
  RealtimeChannel? channel;
  Timer? timer;
  int count = 0;
  bool available = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final user = supabaseClient.auth.currentUser?.id;
    channel = supabaseClient.channel('bell-${DateTime.now().microsecondsSinceEpoch}')
      .onPostgresChanges(event:PostgresChangeEvent.all,schema:'public',table:'notifications',filter:PostgresChangeFilter(type:PostgresChangeFilterType.eq,column:'user_id',value:user ?? ''),callback:(_) => refresh())
      .subscribe((status,_) { if(status == RealtimeSubscribeStatus.subscribed) refresh(); });
    timer = Timer.periodic(const Duration(seconds:45),(_) => refresh());
    PushService.clicked.addListener(onClick);
    unawaited(PushService.sync());
    refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) => onClick());
  }
  Future<void> refresh() async {
    try {
      await AuthService.profile();
      final result = await supabaseClient.from('notifications').count(CountOption.exact).eq('user_id',supabaseClient.auth.currentUser!.id).eq('is_read',false);
      if(mounted) setState(() {count=result;available=true;});
    } catch (_) {if(mounted)setState(() => available=false);}
  }
  void onClick() {
    if(mounted) NotificationNavigation.handle(context);
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if(state==AppLifecycleState.resumed) refresh(); }
  @override
  void dispose() {WidgetsBinding.instance.removeObserver(this);PushService.clicked.removeListener(onClick);timer?.cancel();if(channel!=null)unawaited(supabaseClient.removeChannel(channel!));super.dispose();}
  @override
  Widget build(BuildContext context) => IconButton(tooltip:available?'الإشعارات / Notifications':'تعذر تحديث الإشعارات / Notifications offline',icon:Badge(label:Text(count>99?'99+':'$count'),isLabelVisible:available&&count>0,child:Icon(available?Icons.notifications_outlined:Icons.notifications_off_outlined)),onPressed:() async {
    await Navigator.push(context,MaterialPageRoute<void>(builder:(_) => const NotificationsScreen()));
    refresh();
  });
}
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}
class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String,dynamic>>> data;
  RealtimeChannel? channel;
  bool unread=false;
  int limit=100;
  @override
  void initState() {
    super.initState();reload();
    channel=supabaseClient.channel('notifications-list-${DateTime.now().microsecondsSinceEpoch}')
      .onPostgresChanges(event:PostgresChangeEvent.all,schema:'public',table:'notifications',filter:PostgresChangeFilter(type:PostgresChangeFilterType.eq,column:'user_id',value:supabaseClient.auth.currentUser!.id),callback:(_) {if(mounted)setState(reload);}).subscribe();
  }
  Future<List<Map<String,dynamic>>> load() async {
    await AuthService.profile();
    var q=supabaseClient.from('notifications').select().eq('user_id',supabaseClient.auth.currentUser!.id);
    if(unread) q=q.eq('is_read',false);
    return q.order('created_at',ascending:false).order('id').limit(limit);
  }
  void reload() {data=load();}
  Future<void> action(Future<void> Function() fn) async {try{await fn();if(mounted)setState(reload);}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تعذرت العملية / Operation failed')));}}
  @override
  void dispose(){if(channel!=null)unawaited(supabaseClient.removeChannel(channel!));super.dispose();}
  @override
  Widget build(BuildContext context) => Scaffold(appBar:AppBar(title:const Text('الإشعارات / Notifications'),actions:[
    IconButton(tooltip:'إعدادات الإدارة / Admin setup',icon:const Icon(Icons.settings_outlined),onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const NotificationSettings()))),
    IconButton(tooltip:'المدفوعات / Payments',icon:const Icon(Icons.receipt_long),onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_) => const PaymentsScreen()))),
    IconButton(tooltip:'تفعيل إشعارات الجهاز / Enable device notifications',icon:const Icon(Icons.phonelink_ring),onPressed:()=>action(() async {
      await PushService.sync(requestPermission:true);
    })),
    IconButton(tooltip:'تحديث / Refresh',icon:const Icon(Icons.refresh),onPressed:()=>setState(reload)),
  ]),body:Column(children:[
    ValueListenableBuilder<PushState>(valueListenable:PushService.status,builder:(context,state,_)=>ListTile(leading:Icon(state.registered&&state.enabled?Icons.cloud_done:Icons.cloud_off),title:Text(state.message),subtitle:const Text('حالة الجهاز فقط؛ حالة مفتاح الخادم في الإعدادات / Device status; server credentials checked in settings'))),
    SwitchListTile(title:const Text('غير المقروء فقط / Unread only'),value:unread,onChanged:(v)=>setState(() {unread=v;reload();})),
    TextButton(onPressed:()=>action(()=>supabaseClient.rpc('mark_notifications_read')),child:const Text('تحديد الكل كمقروء / Mark all read')),
    Expanded(child:FutureBuilder<List<Map<String,dynamic>>>(future:data,builder:(context,snapshot){
      if(snapshot.hasError)return const Center(child:Text('تعذر التحميل، أعد المحاولة / Unable to load. Retry.'));
      if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
      final rows=snapshot.data!;
      if(rows.isEmpty)return const Center(child:Text('لا توجد إشعارات / No notifications'));
      return ListView(children:[for(final row in rows)ListTile(
        leading:Icon(row['is_read']==true?Icons.notifications_none:Icons.notifications_active),
        title:Text(row['title'] as String),subtitle:Text('${row['body']}\n${DateTime.parse(row['created_at'] as String).toLocal()}'),
        onTap:()=>openNotification(context,row['id'] as String),
        trailing:IconButton(tooltip:'مقروء / غير مقروء • Read / unread',icon:Icon(row['is_read']==true?Icons.mark_email_unread_outlined:Icons.mark_email_read_outlined),onPressed:()=>action(() async {await supabaseClient.from('notifications').update({'is_read':row['is_read']!=true}).eq('id',row['id']);}))),
        if(rows.length==limit)TextButton(onPressed:()=>setState(() {limit+=100;reload();}),child:const Text('المزيد / More')),
      ]);
    })),
  ]));
}

/// Queries the exact referenced row through current RLS, never trusts push data
/// for role/tenant/authorization. Revoked/deleted references fail closed.
class NotificationReference extends StatefulWidget {
  final String kind,id;
  const NotificationReference({super.key,required this.kind,required this.id});
  @override
  State<NotificationReference> createState()=>_NotificationReferenceState();
}
class _NotificationReferenceState extends State<NotificationReference> {
  late Future<Map<String,dynamic>> data;
  @override
  void initState(){super.initState();data=load();}
  Future<Map<String,dynamic>> load() async {
    final profile=await AuthService.profile();
    final row=await supabaseClient.from(notificationTable(widget.kind)).select().eq('id',widget.id).eq('tenant_id',profile.tenantId).single();
    final invoices=<Map<String,dynamic>>[],reports=<Map<String,dynamic>>[];
    if(widget.kind=='visit') {
      final result=await supabaseClient.from('visit_reports').select('id,status').eq('visit_id',widget.id);
      reports.addAll(result);
    } else if(widget.kind=='report') {
      final links=await supabaseClient.from('report_invoices').select('invoice_id').eq('report_id',widget.id);
      for(final link in links){invoices.addAll(await supabaseClient.from('invoices').select('id,invoice_number').eq('id',link['invoice_id']));}
    }
    return {'profile':profile,'row':row,'reports':reports,'invoices':invoices};
  }
  Future<void> download(String bucket,String path) async {
    try {
      await AuthService.profile();
      final url=await supabaseClient.storage.from(bucket).createSignedUrl(path,300);
      if(!await launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication))throw StateError('No viewer');
    }catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الملف غير متاح / File unavailable')));}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('تفاصيل المرجع / Reference details'),actions:[IconButton(onPressed:()=>setState(()=>data=load()),icon:const Icon(Icons.refresh))]),body:FutureBuilder<Map<String,dynamic>>(future:data,builder:(context,snapshot){
    if(snapshot.hasError)return const Center(child:Text('المرجع غير متاح أو الصلاحية تغيرت / Reference unavailable or access changed'));
    if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
    final result=snapshot.data!,row=Map<String,dynamic>.from(result['row'] as Map);
    final profile=result['profile'] as ProfileAccess;
    return ListView(padding:const EdgeInsets.all(16),children:[
      SelectableText('${widget.kind} — ${widget.id}',style:Theme.of(context).textTheme.titleMedium),
      for(final key in ['invoice_number','status','scheduled_start','scheduled_end','instructions','total','amount_paid','currency','payment_status','payment_review','payment_confirmation_status','payment_reference','submitted_at','findings','actions_taken'])
        if(row[key]!=null)Padding(padding:const EdgeInsets.symmetric(vertical:5),child:SelectableText('$key: ${row[key]}')),
      if(profile.role=='admin'&&((widget.kind=='visit'&&row['status']=='pending_schedule')||(widget.kind=='survey'&&row['status']=='survey_pending')))OutlinedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>Scaffold(appBar:AppBar(title:const Text('إدارة الطلب / Manage request')),body:RequestAdmin(english:Localizations.localeOf(context).languageCode=='en',mode:widget.kind=='survey'?2:1,referenceId:widget.id)))),child:const Text('مراجعة وجدولة هذا الطلب / Review and schedule this request')),
      if(widget.kind=='invoice'&&row['pdf_path']!=null)OutlinedButton(onPressed:()=>download('invoice-pdfs',row['pdf_path'] as String),child:const Text('تحميل الفاتورة / Invoice PDF')),
      if(widget.kind=='report')FutureBuilder<List<Map<String,dynamic>>>(future:supabaseClient.from('document_jobs').select('report_path,status').eq('report_id',widget.id),builder:(context,job){final rows=job.data ?? [];return Column(children:[for(final r in rows)if(r['report_path']!=null)OutlinedButton(onPressed:()=>download('report-pdfs',r['report_path'] as String),child:const Text('تقرير PDF / Report PDF')) else Text('PDF: ${r['status']}')]);}),
      for(final r in result['reports'] as List)OutlinedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>NotificationReference(kind:'report',id:r['id'] as String))),child:const Text('تقرير الزيارة / Visit report')),
      for(final i in result['invoices'] as List)OutlinedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>NotificationReference(kind:'invoice',id:i['id'] as String))),child:Text('${i['invoice_number']}')),
      if(widget.kind=='visit'&&profile.role=='technician')FilledButton(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>TechnicianTasks(english:Localizations.localeOf(context).languageCode=='en',tenant:profile.tenantId,visitId:widget.id))),child:const Text('فتح مهمة الزيارة / Open exact visit task')),
      if(profile.role!='technician'&&(widget.kind=='invoice'||widget.kind=='visit'))PaymentPanel(kind:widget.kind,row:row,profile:profile,onChanged:()=>setState(()=>data=load())),
    ]);
  }));
}

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState()=>_PaymentsScreenState();
}
class _PaymentsScreenState extends State<PaymentsScreen> {
  late Future<List<Map<String,dynamic>>> data;
  @override
  void initState(){super.initState();data=load();}
  Future<List<Map<String,dynamic>>> load() async {
    final profile=await AuthService.profile();
    if(profile.role=='technician')throw const AccessDenied('Client or admin required');
    final rows=<Map<String,dynamic>>[];
    for(final kind in ['invoice','visit']) {
      var query=supabaseClient.from(notificationTable(kind)).select();
      query=kind=='invoice'?query.eq('status','issued').neq('payment_status','paid'):query.eq('status','pending_schedule').isFilter('contract_id',null);
      for(var offset=0;;offset+=100) {
        final page=await query.order('id').range(offset,offset+99);
        rows.addAll(page.map((r)=>{...r,'kind':kind}));
        if(page.length<100)break;
      }
    }
    return rows;
  }
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('الدفع اليدوي ومراجعة الإثبات / Manual payments'),actions:[IconButton(onPressed:()=>setState(()=>data=load()),icon:const Icon(Icons.refresh))]),body:FutureBuilder<List<Map<String,dynamic>>>(future:data,builder:(context,s){
    if(s.hasError)return const Center(child:Text('تعذر التحميل / Unable to load'));
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    if(s.data!.isEmpty)return const Center(child:Text('لا توجد مدفوعات معلقة / No pending payments'));
    return ListView(children:[for(final r in s.data!)ListTile(title:Text('${r['invoice_number']??r['id']}'),subtitle:Text('${r['payment_confirmation_status']??r['payment_review']??r['payment_status']}'),onTap:() async {await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>NotificationReference(kind:r['kind'] as String,id:r['id'] as String)));if(mounted)setState(()=>data=load());})]);
  }));
}

class PaymentPanel extends StatefulWidget {
  final String kind;
  final Map<String,dynamic> row;
  final ProfileAccess profile;
  final VoidCallback onChanged;
  const PaymentPanel({super.key,required this.kind,required this.row,required this.profile,required this.onChanged});
  @override
  State<PaymentPanel> createState()=>_PaymentPanelState();
}
class _PaymentPanelState extends State<PaymentPanel> {
  bool busy=false;
  final reference=TextEditingController();
  @override
  void dispose(){reference.dispose();super.dispose();}
  Future<void> action(Future<void> Function() operation) async {
    if(busy)return;
    setState(()=>busy=true);
    try{await operation();widget.onChanged();}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تعذرت العملية. حدّث وتحقق من الاتصال والصلاحيات / Failed. Refresh and check access/connection.')));}finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> upload() async {
    if(reference.text.trim().length<3)throw const FormatException('Reference required');
    final image=await ImagePicker().pickImage(source:ImageSource.gallery);
    if(image==null)return;
    final bytes=await image.readAsBytes();
    final type=InstapayService.imageType(bytes);
    if(type==null)throw const FormatException('PNG/JPEG max 5MB');
    final user=supabaseClient.auth.currentUser!.id;
    final path='${widget.profile.tenantId}/${widget.row['id']}/$user/${newRequestId()}.${type=='image/png'?'png':'jpg'}';
    await supabaseClient.storage.from('payment-proofs').uploadBinary(path,bytes,fileOptions:FileOptions(contentType:type));
    await supabaseClient.rpc('submit_payment_proof',params:{'target':widget.row['id'],'kind':widget.kind,'object_path':path,'payment_reference':reference.text.trim()});
  }
  Future<void> preview(String path) async {
    final bytes=await supabaseClient.storage.from('payment-proofs').download(path);
    if(!mounted)return;
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('إثبات التحويل / Transfer proof'),content:InteractiveViewer(child:Image.memory(bytes)),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق / Close'))]));
  }
  Future<void> review(bool approved,String? confirmation) async {
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('مراجعة دفع يدوي / Review manual payment'),content:Text(approved?'هل تحققت من استلام المبلغ فعلياً؟ الإيصال وحده ليس إثبات وصول بنكي. / Independently verified the money arrived? A screenshot alone is not bank confirmation.':'رفض إثبات الدفع وإبلاغ العميل؟ / Reject proof and notify client?'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء / Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('تأكيد / Confirm'))]));
    if(ok!=true)return;
    if(widget.kind=='visit'){await supabaseClient.rpc('review_residential_payment',params:{'visit_id':widget.row['id'],'approved':approved});}
    else {await supabaseClient.rpc('review_invoice_payment',params:{'confirmation':confirmation,'approved':approved});}
  }
  @override
  Widget build(BuildContext context){
    final invoice=widget.kind=='invoice',row=widget.row,admin=widget.profile.role=='admin';
    final canUpload=invoice?row['payment_status']!='paid'&&row['status']=='issued'&&row['payment_confirmation_status']!='pending_confirmation':row['contract_id']==null&&row['status']=='pending_schedule'&&['pending_review','rejected'].contains(row['payment_review']);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      if(busy)const LinearProgressIndicator(),
      const Text('إنستا باي فقط — اعتماد يدوي بعد التحقق من وصول المبلغ / InstaPay only, manually verified'),
      if(canUpload)...[
        FutureBuilder<InstapayDestination?>(future:InstapayService.published(),builder:(context,s){if(s.data==null)return const Text('QR غير متاح؛ تواصل مع الإدارة / QR unavailable; contact administration');return Column(children:[Text(s.data!.beneficiary),SizedBox(height:180,child:Image.memory(s.data!.image))]);}),
        TextField(controller:reference,maxLength:200,decoration:const InputDecoration(labelText:'مرجع التحويل / Transfer reference')),
        OutlinedButton(onPressed:busy?null:()=>action(upload),child:const Text('رفع إثبات PNG/JPEG حتى 5MB / Upload transfer proof')),
      ],
      if(row['payment_proof_url']!=null)OutlinedButton(onPressed:busy?null:()=>action(()=>preview(row['payment_proof_url'] as String)),child:const Text('عرض الإثبات / View proof')),
      if(admin&&!invoice&&row['payment_review']=='pending_review')Wrap(children:[for(final approved in [true,false])TextButton(onPressed:busy?null:()=>action(()=>review(approved,null)),child:Text(approved?'تأكيد الاستلام / Confirm receipt':'رفض / Reject'))]),
      if(admin&&invoice)FutureBuilder<List<Map<String,dynamic>>>(future:supabaseClient.from('payment_confirmations').select().eq('invoice_id',row['id']).eq('payment_status','pending_confirmation'),builder:(context,s){return Column(children:[for(final p in s.data??[])Column(children:[Text('${p['amount']} — ${p['reference']}'),TextButton(onPressed:busy?null:()=>action(()=>preview(p['payment_proof_url'] as String)),child:const Text('مراجعة الإيصال / Review receipt')),Wrap(children:[for(final approved in [true,false])TextButton(onPressed:busy?null:()=>action(()=>review(approved,p['id'] as String)),child:Text(approved?'تأكيد الاستلام / Confirm receipt':'رفض / Reject'))])])]);}),
    ]);
  }
}
