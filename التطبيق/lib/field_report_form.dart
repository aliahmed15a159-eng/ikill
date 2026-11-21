import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'field_report_store.dart';
import 'field_report_repository.dart';

const fieldPests = {'rodents':'قوارض / Rodents','cockroaches':'صراصير / Cockroaches','ants':'نمل / Ants','flies':'ذباب / Flies','mosquitoes':'بعوض / Mosquitoes','bedbugs':'بق / Bedbugs','other':'أخرى / Other','none':'لا توجد / None'};
const fieldSeverity = {'none':'لا توجد / None','low':'منخفضة / Low','medium':'متوسطة / Medium','high':'مرتفعة / High'};
const fieldActions = {'inspection':'فحص / Inspection','spraying':'رش / Spraying','baiting':'طعوم / Baiting','traps':'مصائد / Traps','sealing':'سد فتحات / Sealing','sanitation':'نظافة / Sanitation','monitoring':'مراقبة / Monitoring','advice':'توعية / Advice'};

bool validFieldReport(Map<String, dynamic> d) => fieldPests.containsKey(d['pest']) && fieldSeverity.containsKey(d['severity']) &&
  (d['actions'] as List).isNotEmpty && (d['actions'] as List).every(fieldActions.containsKey) &&
  '${d['materials']}'.trim().isNotEmpty && '${d['signer']}'.trim().length >= 2 &&
  (d['strokes'] as List).any((s) => (s as List).length > 1);

class FieldReportForm extends StatefulWidget {
  final String tenant, user, visit;
  final bool english;
  final FieldReportStore store;
  final FieldReportRepository repository;
  const FieldReportForm({super.key, required this.tenant, required this.user, required this.visit, required this.english, required this.store, this.repository=const FieldReportRepository()});
  @override
  State<FieldReportForm> createState() => _FieldReportFormState();
}
class _FieldReportFormState extends State<FieldReportForm> with WidgetsBindingObserver {
  Map<String,dynamic>? draft;
  final materials=TextEditingController(), notes=TextEditingController(), signer=TextEditingController();
  final strokes=<List<Offset>>[];
  Future<void> saving=Future.value();
  bool busy=false, cameraBusy=false, saveFailed=false, saved=false, loadFailed=false, consent=false;
  bool get sealed => draft?['sealed'] == true;
  String tr(String ar,String en)=>widget.english?en:ar;
  @override
  void initState(){super.initState();WidgetsBinding.instance.addObserver(this);load();}
  Future<void> load() async {
    try {
      final d=await widget.store.load(widget.visit) ?? {'submission':reportSubmissionKey(),'pest':'none','severity':'none','actions':<String>[], 'materials':'','notes':'','signer':'','photos':<String>[],'strokes':<dynamic>[]};
      if(!mounted)return;
      materials.text=d['materials'] as String;notes.text=d['notes'] as String;signer.text=d['signer'] as String;
      for(final stroke in d['strokes'] as List){strokes.add([for(final p in stroke as List) Offset((p[0] as num).toDouble(),(p[1] as num).toDouble())]);}
      setState(()=>draft=d);
      if(!Platform.isAndroid)return;
      final pending=await widget.store.readJson('camera.json');
      if(pending is! Map || pending['visit']!=widget.visit)return;
      final lost=await ImagePicker().retrieveLostData();
      if(lost.exception!=null) throw StateError('Camera recovery failed');
      if(lost.files!=null){for(final photo in lost.files!){await keepPhoto(photo.path);}}
      await widget.store.writeJson('camera.json',<String,dynamic>{});
    } catch(_){if(mounted)setState(()=>loadFailed=true);}
  }
  Map<String,dynamic> snapshot()=>{...draft!, 'materials':materials.text,'notes':notes.text,'signer':signer.text,
    'actions':List<String>.from(draft!['actions'] as List),'photos':List<String>.from(draft!['photos'] as List),
    'strokes':[for(final line in strokes)[for(final p in line)[p.dx,p.dy]]]};
  Future<void> persist(){
    if(draft==null)return Future.value();
    final copy=snapshot();
    if(mounted)setState(()=>saved=false);
    saving=saving.then((_) async {
      try{await widget.store.save(widget.visit,copy);if(mounted)setState((){saveFailed=false;saved=true;});}
      catch(_){if(mounted)setState((){saveFailed=true;saved=false;});}
    });
    return saving;
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){if(state!=AppLifecycleState.resumed && draft!=null)persist();}
  @override
  void dispose(){WidgetsBinding.instance.removeObserver(this);materials.dispose();notes.dispose();signer.dispose();super.dispose();}
  Future<void> keepPhoto(String path) async {
    if((draft!['photos'] as List).length>=6)return;
    final file=File(path);if(await file.length()>10485760)throw StateError('Photo exceeds 10 MB');
    final name=await widget.store.keepPhoto(widget.visit,path);
    if(!mounted)return;
    setState(()=>(draft!['photos'] as List).add(name));await persist();
  }
  Future<void> camera() async {
    setState(()=>cameraBusy=true);
    try{
      await persist();if(saveFailed)throw StateError('Local save failed');
      await widget.store.writeJson('camera.json',{'visit':widget.visit});
      final photo=await ImagePicker().pickImage(source:ImageSource.camera,maxWidth:1600,imageQuality:80);
      if(photo!=null)await keepPhoto(photo.path);
      await widget.store.writeJson('camera.json',<String,dynamic>{});
    }catch(_){if(mounted)message(tr('تعذّر حفظ الصورة. تحقق من إذن الكاميرا والمساحة؛ الحد 10 ميجا للصورة.', 'Could not save photo. Check camera permission and space; 10 MB per image maximum.'));}
    finally{if(mounted)setState(()=>cameraBusy=false);}
  }
  void message(String text)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));
  Future<ui.Image> signatureImage() async {
    final recorder=ui.PictureRecorder();final canvas=Canvas(recorder);canvas.drawColor(Colors.white,BlendMode.src);
    SignaturePainter(strokes).paint(canvas,const Size(800,300));
    final picture=recorder.endRecording();final image=await picture.toImage(800,300);picture.dispose();return image;
  }
  Future<void> send() async {
    if(busy||cameraBusy)return;
    final d=snapshot();
    if(!validFieldReport(d)||!consent){message(tr('اختر الإصابة وحالتها وإجراء واحداً على الأقل، واكتب المواد (أو لا يوجد) واسم المسؤول وتوقيعه وموافقته.', 'Choose pest, severity and actions; enter materials (or none), signer name, signature and consent.'));return;}
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(tr('إنهاء وإرسال التقرير؟','Complete and submit report?')),
      content:Text(tr('سيُرفع التقرير والصور والتوقيع ويُغلق التنفيذ. لن يمكن للفني تعديل التقرير بعد الإرسال. عند فشل الاتصال تبقى المسودة؛ أعد الإرسال بنفس الشاشة.', 'Report, photos and signature will upload and the visit will complete. Submitted reports are immutable to technicians. If connection fails, keep the draft and retry here.')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(tr('إلغاء','Cancel'))),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(tr('إرسال','Submit')))]));
    if(confirmed!=true||!mounted)return;
    setState((){busy=true;draft!['sealed']=true;});
    try{
      await persist();if(saveFailed)throw StateError('Local save failed');
      final image=await signatureImage();final bytes=await image.toByteData(format:ui.ImageByteFormat.png);image.dispose();
      if(bytes==null)throw StateError('Signature render failed');
      await widget.repository.submit(widget.tenant,widget.user,widget.visit,d,widget.store,bytes.buffer.asUint8List());
      // Only remove local evidence after the server acknowledges atomic commit.
      try{await widget.store.remove(widget.visit);}catch(_){/* A retained local copy is safer than data loss. */}
      if(mounted){message(tr('تم إرسال التقرير وإنهاء الزيارة','Report submitted and visit completed'));Navigator.pop(context,true);}
    }catch(_){if(mounted)message(tr('لم نتأكد من الإرسال. المسودة محفوظة على هذا الهاتف؛ تحقق من الشبكة والتعيين ثم أعد الإرسال. لا تمسح بيانات التطبيق.', 'Submission not confirmed. Draft remains on this phone. Check network and assignment then retry. Do not clear app data.'));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context)=>PopScope(canPop:!busy&&!cameraBusy,onPopInvokedWithResult:(didPop,result){if(didPop&&draft!=null)persist();},child:Scaffold(
    appBar:AppBar(title:Text(tr('تقرير الزيارة الرقمي','Digital visit report'))),
    body:loadFailed?Center(child:Text(tr('تعذّر استرجاع المسودة أو الكاميرا. أغلق الشاشة وأعد فتحها؛ لا تمسح بيانات التطبيق.', 'Draft/camera recovery failed. Reopen this screen; do not clear app data.'))):draft==null?const Center(child:CircularProgressIndicator()):AbsorbPointer(absorbing:busy||cameraBusy,child:ListView(padding:const EdgeInsets.all(16),children:[
      if(busy||cameraBusy)const LinearProgressIndicator(),
      Text(saveFailed?tr('فشل الحفظ المحلي! تحقق من المساحة ولا تغلق الشاشة.','Local save failed! Check free space; do not close.'):saved?tr('المسودة محفوظة على الهاتف','Draft saved on this phone'):tr('جارٍ حفظ المسودة…','Saving draft…'),style:TextStyle(color:saveFailed?Colors.red:Colors.green)),
      if(sealed)Text(tr('تم تثبيت بيانات محاولة الإرسال لمنع اختلاف النسخ. أعد الإرسال كما هي عند عودة الاتصال.', 'Submission snapshot is locked to prevent conflicting retries. Retry unchanged when connected.')),
      Text(tr('يمكن تعبئة التقرير بلا إنترنت بعد بدء الزيارة. الإرسال يتطلب اتصالاً. المسودات خاصة بهذا الحساب على هذا الهاتف؛ حذف التطبيق أو بياناته يحذفها.', 'Fill offline after starting the visit. Submission needs internet. Drafts belong to this account on this phone; uninstalling or clearing app data removes them.')),
      DropdownButtonFormField<String>(value:draft!['pest'] as String,decoration:InputDecoration(labelText:tr('نوع الإصابة','Pest type')),items:[for(final e in fieldPests.entries)DropdownMenuItem(value:e.key,child:Text(e.value))],onChanged:sealed?null:(v){setState(()=>draft!['pest']=v);persist();}),
      DropdownButtonFormField<String>(value:draft!['severity'] as String,decoration:InputDecoration(labelText:tr('حالة الإصابة','Severity')),items:[for(final e in fieldSeverity.entries)DropdownMenuItem(value:e.key,child:Text(e.value))],onChanged:sealed?null:(v){setState(()=>draft!['severity']=v);persist();}),
      const SizedBox(height:12),Text(tr('الإجراءات المنفذة','Actions performed')),
      for(final e in fieldActions.entries)CheckboxListTile(contentPadding:EdgeInsets.zero,title:Text(e.value),value:(draft!['actions'] as List).contains(e.key),onChanged:sealed?null:(v){setState((){final a=draft!['actions'] as List;v==true?a.add(e.key):a.remove(e.key);});persist();}),
      TextField(readOnly:sealed,controller:materials,maxLength:4000,maxLines:3,decoration:InputDecoration(labelText:tr('المواد المستخدمة والكميات / لا يوجد','Materials and quantities / none')),onChanged:(_)=>persist()),
      TextField(readOnly:sealed,controller:notes,maxLength:8000,maxLines:4,decoration:InputDecoration(labelText:tr('ملاحظات وتوصيات','Notes and recommendations')),onChanged:(_)=>persist()),
      Text(tr('الصور: حتى 6، بعد موافقة الموقع','Photos: up to 6, with site permission')),
      for(final name in List<String>.from(draft!['photos'] as List))FutureBuilder<File>(future:widget.store.photo(widget.visit,name),builder:(context,snapshot)=>snapshot.hasData?Column(children:[Image.file(snapshot.data!,height:160,errorBuilder:(_,error,stack)=>Text(tr('الصورة غير متاحة؛ أعد التقاطها','Photo unavailable; retake'))),TextButton(onPressed:sealed?null:(){setState(()=>(draft!['photos'] as List).remove(name));persist();},child:Text(tr('إزالة الصورة','Remove photo')))]):const SizedBox()),
      OutlinedButton.icon(onPressed:sealed||(draft!['photos'] as List).length>=6?null:camera,icon:const Icon(Icons.camera_alt),label:Text(tr('التقاط صورة','Take photo'))),
      TextField(readOnly:sealed,controller:signer,maxLength:160,decoration:InputDecoration(labelText:tr('اسم مسؤول الموقع الموقّع','Site representative name')),onChanged:(_)=>persist()),
      Text(tr('توقيع مسؤول الموقع — ارسم داخل المربع','Site representative signature — draw in the box')),
      LayoutBuilder(builder:(context,constraints)=>Container(height:180,decoration:BoxDecoration(color:Colors.white,border:Border.all(color:Colors.grey)),child:GestureDetector(
        onPanStart:sealed?null:(d){setState(()=>strokes.add([Offset((d.localPosition.dx/constraints.maxWidth).clamp(0,1),(d.localPosition.dy/180).clamp(0,1))]));},
        onPanUpdate:sealed?null:(d){setState(()=>strokes.last.add(Offset((d.localPosition.dx/constraints.maxWidth).clamp(0,1),(d.localPosition.dy/180).clamp(0,1))));},
        onPanEnd:sealed?null:(_)=>persist(),onPanCancel:sealed?null:()=>persist(),child:CustomPaint(painter:SignaturePainter(strokes),size:Size(constraints.maxWidth,180))))),
      TextButton(onPressed:sealed?null:(){setState(()=>strokes.clear());persist();},child:Text(tr('مسح التوقيع','Clear signature'))),
      CheckboxListTile(value:consent,onChanged:(v)=>setState(()=>consent=v==true),title:Text(tr('أقرّ بموافقة مسؤول الموقع على تسجيل توقيعه وإرساله مع التقرير. هذا توقيع مرسوم وليس خدمة توقيع معتمدة.', 'The site representative consents to recording and submitting this drawn signature. This is not a certified digital-signature service.'))),
      OutlinedButton(onPressed:persist,child:Text(tr('حفظ المسودة محلياً','Save draft locally'))),
      FilledButton(onPressed:send,child:Text(tr('إنهاء وإرسال التقرير','Complete and submit report'))),
    ])))) ;
}
class SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  SignaturePainter(this.strokes);
  @override
  void paint(Canvas canvas,Size size){final pen=Paint()..color=Colors.black..strokeWidth=2.5..strokeCap=StrokeCap.round;
    for(final line in strokes){for(var i=1;i<line.length;i++){canvas.drawLine(Offset(line[i-1].dx*size.width,line[i-1].dy*size.height),Offset(line[i].dx*size.width,line[i].dy*size.height),pen);}}}
  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate)=>true;
}
