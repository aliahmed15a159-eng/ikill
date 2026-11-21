import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin.dart';
import 'auth_service.dart';
import 'backend.dart';
import 'supabase_client.dart';
import 'documents_repository.dart';

class ClientPortalPage extends StatelessWidget {
  final bool english;
  const ClientPortalPage({super.key,required this.english});
  @override
  Widget build(BuildContext context){
    if(!Backend.ready)return Scaffold(appBar:AppBar(title:Text(english?'Client portal':'بوابة العميل')),body:const Center(child:Text('Configure Supabase')));
    return StreamBuilder<AuthState>(stream:supabaseClient.auth.onAuthStateChange,builder:(context,state){
      if(supabaseClient.auth.currentSession==null)return AdminLogin(english:english,client:true);
      return FutureBuilder<ProfileAccess>(future:AuthService.profile(),builder:(context,profile){
        if(profile.hasError||profile.hasData&&profile.data!.role!='client')return Scaffold(appBar:AppBar(title:Text(english?'Client portal':'بوابة العميل')),body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(english?'An enabled client account is required.':'يلزم حساب عميل فعّال ومصرح له بالبوابة.'),TextButton(onPressed:()=>supabaseClient.auth.signOut(),child:Text(english?'Sign out':'خروج'))])));
        if(!profile.hasData)return const Scaffold(body:Center(child:CircularProgressIndicator()));
        return Scaffold(appBar:AppBar(title:Text(english?'My sites, visits and documents':'فروعي وزياراتي ومستنداتي'),actions:[IconButton(onPressed:()=>supabaseClient.auth.signOut(),icon:const Icon(Icons.logout))]),body:DocumentsScreen(english:english,portal:true));
      });
    });
  }
}
Map<String,dynamic>? documentJob(Map<String,dynamic> report){final value=report['document_jobs'];if(value is Map)return Map<String,dynamic>.from(value);if(value is List&&value.isNotEmpty)return Map<String,dynamic>.from(value.first as Map);return null;}
class DocumentsScreen extends StatefulWidget {
  final bool english,portal;
  final String? client;
  final DocumentsRepository repository;
  const DocumentsScreen({super.key,required this.english,this.portal=false,this.client,this.repository=const DocumentsRepository()});
  @override
  State<DocumentsScreen> createState()=>_DocumentsScreenState();
}
class _DocumentsScreenState extends State<DocumentsScreen> with WidgetsBindingObserver {
  late Future<Map<String,dynamic>> data;
  bool busy=false;
  Timer? timer,debounce;RealtimeChannel? channel;
  final attempted=<String>{};
  String tr(String ar,String en)=>widget.english?en:ar;
  @override
  void initState(){super.initState();WidgetsBinding.instance.addObserver(this);data=load();timer=Timer.periodic(const Duration(seconds:60),(_)=>refresh());}
  void changed(){debounce?.cancel();debounce=Timer(const Duration(milliseconds:500),refresh);}
  Future<Map<String,dynamic>> load() async {
    final result=await widget.repository.load(client:widget.client,portal:widget.portal);
    if(mounted&&channel==null){channel=await widget.repository.watch(result['tenant'] as String,(){if(mounted)changed();});if(!mounted){await supabaseClient.removeChannel(channel!);channel=null;}}
    // Durable pending jobs are retried on opening a portal/admin archive; a
    // maximum of three automatic attempts per screen avoids infinite loops.
    final candidates=List<Map<String,dynamic>>.from(result['reports'] as List).where((r){final j=documentJob(r);return j!=null&&j['status']!='ready'&&!attempted.contains(r['id']);}).take(3).toList();
    for(final r in candidates){attempted.add(r['id'] as String);unawaited(widget.repository.generate(r['id'] as String).then((_){if(mounted)changed();}).catchError((_){/* Show pending/failed state; manual retry is available. */}));}
    return result;
  }
  void refresh(){if(mounted)setState(()=>data=load());}
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed)refresh();}
  @override
  void dispose(){WidgetsBinding.instance.removeObserver(this);timer?.cancel();debounce?.cancel();final c=channel;if(c!=null)supabaseClient.removeChannel(c);super.dispose();}
  Future<void> action(Future<void> Function() fn) async {
    if(busy)return;setState(()=>busy=true);
    try{await fn();refresh();}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(tr('تعذّرت العملية. تحقق من الصلاحيات والاتصال. قد تكون ملفات PDF قيد التجهيز؛ أعد المحاولة.', 'Operation failed. Check access/connection. PDFs may still be processing; retry.'))));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> open(Uri uri) async {if(!await launchUrl(uri,mode:LaunchMode.externalApplication))throw StateError('External app unavailable');}
  Future<void> download(String bucket,String path) async=>open(Uri.parse(await widget.repository.url(bucket,path)));
  Future<void> share(Map<String,dynamic> report,Map<String,dynamic> invoice,bool email) async {
    final j=documentJob(report);if(j?['report_path']==null||invoice['pdf_path']==null)throw StateError('PDF pending');
    final accepted=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(tr('مشاركة مستندات خاصة؟','Share private documents?')),content:Text(tr('الروابط صالحة 24 ساعة ويمكن لأي شخص تُعاد توجيهها إليه فتحها حتى انتهائها. راجع رقم العميل/إيميله قبل تأكيد الإرسال في التطبيق الخارجي.','Links last 24 hours and anyone receiving a forwarded link can open them until expiry. Verify the recipient before sending in the external app.')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(tr('إلغاء','Cancel'))),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(tr('متابعة','Continue')))]));
    if(accepted!=true)return;
    final client=invoice['clients'] as Map? ?? {};
    final reportUrl=await widget.repository.url('report-pdfs',j!['report_path'] as String,share:true);
    final invoiceUrl=await widget.repository.url('invoice-pdfs',invoice['pdf_path'] as String,share:true);
    final message='مرحباً ${client['display_name']??''}، مرفق تقرير الزيارة والفاتورة ${invoice['invoice_number']}.\nتقرير الزيارة: $reportUrl\nالفاتورة: $invoiceUrl\nالروابط صالحة لمدة 24 ساعة. / Links expire in 24 hours.';
    if(email){final recipient='${client['email']??''}'.trim();if(!recipient.contains('@'))throw const FormatException('Client email required');await open(Uri(scheme:'mailto',path:recipient,query:'subject=${Uri.encodeComponent('تقرير الزيارة والفاتورة / Visit report and invoice')}&body=${Uri.encodeComponent(message)}'));}
    else{final phone=whatsappPhone('${client['phone']??''}');await open(Uri.https('wa.me','/$phone',{'text':message}));}
  }
  Future<void> collect(Map<String,dynamic> invoice) async {
    final reference=await showDialog<String>(context:context,builder:(_)=>CollectionDialog(english:widget.english,total:'${invoice['total']} ${invoice['currency']}'));
    if(reference==null)return;
    await action(()async{await widget.repository.paid(invoice['id'] as String,reference);attempted.clear();});
  }
  @override
  Widget build(BuildContext context)=>Column(children:[if(busy)const LinearProgressIndicator(),Row(children:[Expanded(child:Padding(padding:const EdgeInsets.all(12),child:Text(tr('التقارير والفواتير','Reports and invoices'),style:Theme.of(context).textTheme.titleLarge))),IconButton(onPressed:busy?null:(){attempted.clear();refresh();},icon:const Icon(Icons.refresh))]),Expanded(child:FutureBuilder<Map<String,dynamic>>(future:data,builder:(context,snapshot){
    if(snapshot.hasError)return Center(child:Text(tr('تعذّر التحميل أو أُلغيت صلاحية البوابة. استخدم التحديث أو تواصل مع الإدارة.','Load failed or portal access was disabled. Refresh or contact administration.')));
    if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
    final d=snapshot.data!,invoices=List<Map<String,dynamic>>.from(d['invoices'] as List),reports=List<Map<String,dynamic>>.from(d['reports'] as List);
    return ListView(padding:const EdgeInsets.all(12),children:[
      if(widget.portal)...[
        Text(tr('فروعي','My sites'),style:Theme.of(context).textTheme.titleLarge),
        for(final s in d['sites'] as List)ListTile(title:Text('${s['name']}'),subtitle:Text('${s['address']}')),
        Text(tr('زياراتي القادمة — توقيت الجهاز','Upcoming visits — device time'),style:Theme.of(context).textTheme.titleLarge),
        for(final v in d['visits'] as List)ListTile(title:Text('${(v['client_sites'] as Map?)?['name']} — ${v['status']}'),subtitle:Text('${DateTime.parse(v['scheduled_start'] as String).toLocal()}')),
      ],
      Text(tr('أرشيف التقارير','Report archive'),style:Theme.of(context).textTheme.titleLarge),
      if(reports.isEmpty)Text(tr('لا توجد تقارير مرسلة بعد','No submitted reports yet')),
      for(final r in reports)Builder(builder:(_){final j=documentJob(r);final link=r['report_invoices'];final id=link is Map?link['invoice_id']:link is List&&link.isNotEmpty?link.first['invoice_id']:null;final linked=invoices.where((i)=>i['id']==id).toList();final invoice=linked.isEmpty?null:linked.first;
        return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${(r['visits'] as Map?)?['client_sites']?['name']??''} — ${r['submitted_at']}'),
          Text(j==null?tr('تقرير سابق: يحتاج إعداد مستنداته بواسطة الإدارة','Legacy report: administration must prepare its documents'):'PDF: ${j['status']}'),
          Wrap(spacing:8,runSpacing:4,children:[
            if(j?['report_path']!=null)OutlinedButton(onPressed:busy?null:()=>action(()=>download('report-pdfs',j!['report_path'] as String)),child:Text(tr('تحميل تقرير PDF','Download report PDF'))),
            if(j!=null&&j['status']!='ready')OutlinedButton(onPressed:busy?null:()=>action(()=>widget.repository.generate(r['id'] as String)),child:Text(tr('إعادة تجهيز PDF','Retry PDF generation'))),
            if(!widget.portal&&invoice!=null&&j?['report_path']!=null&&invoice['pdf_path']!=null)...[
              OutlinedButton(onPressed:busy?null:()=>action(()=>share(r,invoice,false)),child:const Text('WhatsApp')),
              OutlinedButton(onPressed:busy?null:()=>action(()=>share(r,invoice,true)),child:const Text('Email')),
            ],
          ]),
        ])));
      }),
      const Divider(),Text(tr('فواتيري','Invoices'),style:Theme.of(context).textTheme.titleLarge),
      for(final i in invoices)Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        SelectableText('${i['invoice_number']}\n${i['total']} ${i['currency']} — ${i['payment_status']}\n${tr('المحصّل','Collected')}: ${i['amount_paid']} — ${tr('الاستحقاق','Due')}: ${i['due_on']}'),
        if(i['billing_period']!=null)Text('${i['billing_period']} — ${i['period_end']}'),
        Wrap(spacing:8,children:[
          if(i['pdf_path']!=null)OutlinedButton(onPressed:busy?null:()=>action(()=>download('invoice-pdfs',i['pdf_path'] as String)),child:Text(tr('تحميل فاتورة PDF','Download invoice PDF'))),
          if(!widget.portal&&i['payment_status']!='paid')FilledButton(onPressed:busy?null:()=>collect(i),child:Text(tr('تسجيل التحصيل بالكامل','Record full collection'))),
        ]),
      ]))),
    ]);
  }))]);
}
class CollectionDialog extends StatefulWidget {
  final bool english;final String total;
  const CollectionDialog({super.key,required this.english,required this.total});
  @override
  State<CollectionDialog> createState()=>_CollectionDialogState();
}
class _CollectionDialogState extends State<CollectionDialog>{
  final controller=TextEditingController();
  @override
  void dispose(){controller.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>AlertDialog(title:Text(widget.english?'Confirm manual collection':'تأكيد التحصيل اليدوي'),content:Column(mainAxisSize:MainAxisSize.min,children:[Text('${widget.total}\n${widget.english?'Confirms the remaining balance was actually received. No bank transfer is performed.':'يؤكد استلام المتبقي فعلياً. لا ينفذ تحويلاً بنكياً.'}'),TextField(controller:controller,maxLength:200,decoration:InputDecoration(labelText:widget.english?'Collection reference / receipt':'مرجع التحصيل / الإيصال'),onChanged:(_)=>setState((){}))]),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:Text(widget.english?'Cancel':'إلغاء')),FilledButton(onPressed:controller.text.trim().length<3?null:()=>Navigator.pop(context,controller.text.trim()),child:Text(widget.english?'Confirm collected':'تأكيد الاستلام'))]);
}
