import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'auth_service.dart';
import 'supabase_client.dart';
import 'field_report_store.dart';
import 'documents_screen.dart';

class PortalAdminCard extends StatefulWidget {
  final String client;final bool english;
  const PortalAdminCard({super.key,required this.client,required this.english});
  @override
  State<PortalAdminCard> createState()=>_PortalAdminCardState();
}
class _PortalAdminCardState extends State<PortalAdminCard>{
  late Future<Map<String,dynamic>> data=load();bool busy=false;
  String tr(String ar,String en)=>widget.english?en:ar;
  Future<Map<String,dynamic>> load()async{final a=await AuthService.requireAdmin();return {'client':await supabaseClient.from('clients').select('portal_enabled,email').eq('tenant_id',a.tenantId).eq('id',widget.client).single(),'accounts':await supabaseClient.from('profiles').select('id,full_name,is_active,portal_enabled').eq('tenant_id',a.tenantId).eq('client_id',widget.client).eq('role','client')};}
  Future<void> action(Future<void> Function() fn)async{setState(()=>busy=true);try{await fn();if(mounted)setState(()=>data=load());}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(tr('تعذّرت العملية. قد يكون البريد أو العميل مرتبطاً بحساب قائم. لا تُعاد تهيئة حساب قائم تلقائياً.','Operation failed. Email/client may already have an account; existing accounts are never silently reset.'))));}finally{if(mounted)setState(()=>busy=false);}}
  @override
  Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:FutureBuilder<Map<String,dynamic>>(future:data,builder:(context,snapshot){
    if(snapshot.hasError)return TextButton(onPressed:()=>setState(()=>data=load()),child:Text(tr('إعادة تحميل صلاحيات البوابة','Retry portal access')));
    if(!snapshot.hasData)return const LinearProgressIndicator();final client=snapshot.data!['client'] as Map,accounts=snapshot.data!['accounts'] as List;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      SwitchListTile(contentPadding:EdgeInsets.zero,title:Text(tr('تفعيل بوابة العميل الانتقائية','Enable selective client portal')),subtitle:Text(tr('لا يتيح إنشاء حساب التسجيل العام؛ الحساب يرى بيانات هذا العميل فقط.','No public signup. Account sees this client only.')),value:client['portal_enabled']==true,onChanged:busy?null:(v)=>action(()=>supabaseClient.rpc('set_client_portal',params:{'customer':widget.client,'enabled':v}))),
      if(accounts.isNotEmpty)Text(tr('يوجد حساب مرتبط بالعميل؛ تعطيل البوابة يمنع الوصول الجديد لبياناته.','A client account already exists; disabling portal blocks new data access.')),
      if(accounts.isEmpty)OutlinedButton(onPressed:busy?null:()async{final credentials=await showDialog<Map<String,String>>(context:context,builder:(_)=>CreateClientAccountDialog(english:widget.english,email:'${client['email']??''}'));if(credentials==null)return;await action(()async{await supabaseClient.functions.invoke('app-documents',body:{'action':'create-client-account','client_id':widget.client,...credentials});});},child:Text(tr('إنشاء حساب Email وكلمة مرور','Create email/password account'))),
      OutlinedButton(onPressed:busy?null:()=>Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>Scaffold(appBar:AppBar(title:Text(tr('مستندات العميل','Client documents'))),body:DocumentsScreen(english:widget.english,client:widget.client)))),child:Text(tr('تقارير وفواتير العميل والتحصيل','Client reports, invoices and collection'))),
      if(busy)const LinearProgressIndicator(),
    ]);
  })));
}
class CreateClientAccountDialog extends StatefulWidget{
  final bool english;final String email;
  const CreateClientAccountDialog({super.key,required this.english,required this.email});
  @override
  State<CreateClientAccountDialog> createState()=>_CreateClientAccountDialogState();
}
class _CreateClientAccountDialogState extends State<CreateClientAccountDialog>{
  late final email=TextEditingController(text:widget.email);final password=TextEditingController();final form=GlobalKey<FormState>();
  @override
  void dispose(){email.dispose();password.clear();password.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>AlertDialog(title:Text(widget.english?'Provision selected client account':'إنشاء حساب للعميل المحدد'),content:SingleChildScrollView(child:Form(key:form,child:Column(mainAxisSize:MainAxisSize.min,children:[
    Text(widget.english?'Share credentials securely outside document messages. This does not reset an existing account.':'سلّم بيانات الدخول بشكل آمن، وليس داخل رسائل المستندات. لا يُغيّر حساباً قائماً.'),
    TextFormField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email'),validator:(v)=>v!=null&&RegExp(r'^\S+@\S+\.\S+$').hasMatch(v)?null:'Email'),
    TextFormField(controller:password,obscureText:true,enableSuggestions:false,autocorrect:false,maxLength:128,decoration:InputDecoration(labelText:widget.english?'Password (12+ characters)':'كلمة مرور (12 حرفاً على الأقل)'),validator:(v)=>v!=null&&v.length>=12?null:'12+'),
  ]))),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:Text(widget.english?'Cancel':'إلغاء')),FilledButton(onPressed:(){if(form.currentState!.validate())Navigator.pop(context,{'email':email.text.trim(),'password':password.text});},child:Text(widget.english?'Create':'إنشاء'))]);
}

class DocumentBrandSettings extends StatefulWidget{
  final bool english;const DocumentBrandSettings({super.key,required this.english});
  @override
  State<DocumentBrandSettings> createState()=>_DocumentBrandSettingsState();
}
class _DocumentBrandSettingsState extends State<DocumentBrandSettings>{
  final fields=<String,TextEditingController>{for(final key in ['company_name','address','phone','email','tax_number','primary_hex'])key:TextEditingController()};
  String? tenant,logo,error;bool busy=false,loaded=false;
  String tr(String ar,String en)=>widget.english?en:ar;
  @override
  void initState(){super.initState();load();}
  @override
  void dispose(){for(final c in fields.values){c.dispose();}super.dispose();}
  Future<void> load()async{try{final a=await AuthService.requireAdmin();final b=await supabaseClient.from('brand_config').select().eq('tenant_id',a.tenantId).single();if(!mounted)return;for(final e in fields.entries){e.value.text='${b[e.key]??''}';}setState((){tenant=a.tenantId;logo=b['logo_path'] as String?;loaded=true;});}catch(_){if(mounted)setState(()=>error=tr('تعذّر تحميل إعدادات المستندات','Could not load document branding'));}}
  Future<void> save()async{
    if(fields['company_name']!.text.trim().isEmpty||!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(fields['primary_hex']!.text.trim())){setState(()=>error=tr('يلزم اسم الشركة ولون HEX من 6 خانات دون #','Company name and six-digit HEX color without # required'));return;}
    setState((){busy=true;error=null;});try{await AuthService.requireAdmin();await supabaseClient.from('brand_config').update({for(final e in fields.entries)e.key:e.value.text.trim(),'logo_path':logo}).eq('tenant_id',tenant!);if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(tr('تم الحفظ. تُستخدم البيانات في ملفات PDF الجديدة؛ المستندات المرسلة سابقاً لا تتغير تلقائياً.','Saved for new PDFs; previously published documents are not automatically rewritten.'))));}catch(_){if(mounted)setState(()=>error=tr('فشل الحفظ؛ تحقق من طول الحقول والصلاحيات','Save failed; check field lengths and access'));}finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> upload({bool defaultLogo=false})async{
    setState(()=>busy=true);try{
      await AuthService.requireAdmin();final picked=defaultLogo?null:await ImagePicker().pickImage(source:ImageSource.gallery,maxWidth:1200,imageQuality:90);
      if(!defaultLogo&&picked==null)return;
      final bytes=defaultLogo?(await rootBundle.load('assets/images/ikill-logo-transparent.png')).buffer.asUint8List():await picked!.readAsBytes();
      if(bytes.length>2097152)throw StateError('Max 2 MB');
      final png=defaultLogo||picked!.name.toLowerCase().endsWith('.png');final path='$tenant/logo-${reportSubmissionKey()}.${png?'png':'jpg'}';
      await supabaseClient.storage.from('brand-assets').uploadBinary(path,bytes,fileOptions:FileOptions(contentType:png?'image/png':'image/jpeg'));
      if(mounted)setState(()=>logo=path);
    }catch(_){if(mounted)setState(()=>error=tr('تعذّر رفع الشعار؛ الحد 2 ميجا، PNG أو JPG.','Logo upload failed; maximum 2 MB PNG/JPG.'));}finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
    Text(tr('هوية الشركة على PDF — brand_config','PDF company identity — brand_config'),style:Theme.of(context).textTheme.titleLarge),
    if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),if(!loaded||busy)const LinearProgressIndicator(),
    for(final e in fields.entries)Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:e.value,enabled:loaded&&!busy,maxLength:e.key=='address'?600:e.key=='company_name'?160:e.key=='email'?254:e.key=='phone'?40:e.key=='tax_number'?80:6,decoration:InputDecoration(labelText:{'company_name':tr('اسم الشركة','Company name'),'address':tr('العنوان','Address'),'phone':tr('الهاتف','Phone'),'email':'Email','tax_number':tr('الرقم الضريبي (اختياري)','Tax number (optional)'),'primary_hex':tr('لون الهوية HEX','Brand HEX color')}[e.key]))),
    Text('${tr('مسار الشعار','Logo path')}: ${logo??'—'}'),
    OutlinedButton(onPressed:loaded&&!busy?upload:null,child:Text(tr('رفع شعار من الصور','Upload logo from photos'))),
    OutlinedButton(onPressed:loaded&&!busy?()=>upload(defaultLogo:true):null,child:Text(tr('استخدام شعار التطبيق الحالي','Use current app logo'))),
    FilledButton(onPressed:loaded&&!busy?save:null,child:Text(tr('حفظ هوية المستندات','Save document branding'))),
  ]);
}
