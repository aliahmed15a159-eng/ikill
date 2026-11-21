import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'push_service.dart';
import 'supabase_client.dart';

class NotificationSettings extends StatefulWidget {
  const NotificationSettings({super.key});
  @override
  State<NotificationSettings> createState()=>_NotificationSettingsState();
}
class _NotificationSettingsState extends State<NotificationSettings> {
  bool enabled=false,busy=false;
  late Future<Map<String,dynamic>> data;
  @override
  void initState(){super.initState();data=load();}
  Future<Map<String,dynamic>> load() async {
    await AuthService.requireAdmin();
    final settings=Map<String,dynamic>.from(await supabaseClient.rpc('get_notification_settings') as Map);
    enabled=settings['push_enabled']==true;
    try {
      final response=await supabaseClient.functions.invoke('push-notification',body:{'action':'status'});
      settings['server_configured']=(response.data as Map?)?['configured']==true;
    } catch(_){settings['server_configured']=null;}
    return settings;
  }
  Future<void> action(bool retry) async {
    setState(()=>busy=true);
    try {
      await AuthService.requireAdmin();
      if(retry){await supabaseClient.rpc('retry_notification_pushes');}
      else {await supabaseClient.rpc('set_notification_push_settings',params:{'enabled':enabled});}
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم حفظ الطلب؛ هذا ليس تأكيد وصول إشعار / Saved; not proof of delivery')));
    } catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تعذرت العملية / Operation failed')));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('حالة FCM / Push status'),actions:[IconButton(onPressed:busy?null:()=>setState(()=>data=load()),icon:const Icon(Icons.refresh))]),body:FutureBuilder<Map<String,dynamic>>(future:data,builder:(context,s){
    if(s.hasError)return const Center(child:Text('للإدارة فقط / Administrators only'));
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    final server=s.data!['server_configured'];
    return ListView(padding:const EdgeInsets.all(16),children:[
      if(busy)const LinearProgressIndicator(),
      const Text('FCM للإشعارات الخارجية فقط. Supabase هو المسؤول الوحيد عن الحسابات والبيانات والملفات وجرس التطبيق. / FCM is mobile push transport only; Supabase owns Auth, data, files and realtime notifications.'),
      ValueListenableBuilder<PushState>(valueListenable:PushService.status,builder:(context,state,_)=>ListTile(leading:Icon(state.registered?Icons.phonelink_ring:Icons.phonelink_erase),title:Text(state.message))),
      Text('FCM project: ${s.data!['project_id']}'),
      Text('Database webhook: ${s.data!['webhook_enabled']==true?'enabled':'not configured'}'),
      Text(server==true?'حساب خدمة الخادم: موجود وصيغته ومشروعه صالحان؛ لم يُختبر وصول فعلي / Server credentials present and valid in format/project; delivery not verified':server==false?'حساب خدمة الخادم مفقود أو غير صالح أو مشروعه غير مطابق / Server service account missing, invalid or project mismatch':'تعذر فحص إعداد الخادم / Server status unavailable'),
      const Text('احفظ JSON حساب الخدمة في Supabase → Edge Functions → Secrets باسم FIREBASE_SERVICE_ACCOUNT فقط. لا تضع المفتاح الخاص هنا أو في المحادثة أو داخل التطبيق. ملف google-services.json إعداد عميل وليس حساب خدمة. / Server private credentials belong only in Supabase Secrets.'),
      SwitchListTile(title:const Text('السماح بالإرسال الخارجي / Enable external sending'),value:enabled,onChanged:busy?null:(v)=>setState(()=>enabled=v)),
      FilledButton(onPressed:busy?null:()=>action(false),child:const Text('حفظ / Save')),
      OutlinedButton(onPressed:busy?null:()=>PushService.sync(requestPermission:true),child:const Text('طلب الصلاحية وتسجيل هذا الجهاز / Request permission and register device')),
      OutlinedButton(onPressed:busy?null:()=>action(true),child:const Text('إعادة محاولة غير المرسل خلال 24 ساعة / Retry unsent from last 24h')),
    ]);
  }));
}
