import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'supabase_client.dart';

class NotificationSettings extends StatefulWidget {
  const NotificationSettings({super.key});
  @override
  State<NotificationSettings> createState()=>_NotificationSettingsState();
}
class _NotificationSettingsState extends State<NotificationSettings> {
  final app=TextEditingController();
  bool enabled=false,busy=false;
  late Future<Map<String,dynamic>> data;
  @override
  void initState(){super.initState();data=load();}
  Future<Map<String,dynamic>> load() async {
    await AuthService.requireAdmin();
    final settings=Map<String,dynamic>.from(await supabaseClient.rpc('get_notification_settings') as Map);
    app.text=settings['app_id'] as String? ?? '';
    enabled=settings['push_enabled']==true;
    return settings;
  }
  @override
  void dispose(){app.dispose();super.dispose();}
  Future<void> action(bool retry) async {
    setState(()=>busy=true);
    try {
      await AuthService.requireAdmin();
      if(retry){await supabaseClient.rpc('retry_notification_pushes');}
      else {await supabaseClient.rpc('set_notification_push_settings',params:{'app_id':app.text.trim().isEmpty?null:app.text.trim(),'enabled':enabled});}
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم / Done')));
    } catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تعذرت العملية. تحقق من App ID والصلاحيات / Check App ID and permissions')));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('إعداد إشعارات الجهاز / Device push setup')),body:FutureBuilder<Map<String,dynamic>>(future:data,builder:(context,s){
    if(s.hasError)return const Center(child:Text('للإدارة فقط / Administrators only'));
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    return ListView(padding:const EdgeInsets.all(16),children:[
      if(busy)const LinearProgressIndicator(),
      const Text('إشعارات التطبيق تعمل عبر Supabase دون هذه الإعدادات. إرسال إشعارات الهاتف يحتاج تطبيق OneSignal وإعداد مزود Android/iOS ومفتاح API على الخادم. تفعيل الزر وحده لا يثبت نجاح الإرسال. / In-app notifications are independent. Device push needs OneSignal, platform transport credentials and a server-side API key. This switch alone does not verify delivery.'),
      Text('Database webhook: ${s.data!['webhook_enabled']==true?'enabled':'not configured'}'),
      TextField(controller:app,decoration:const InputDecoration(labelText:'OneSignal App ID (public UUID)')),
      const Text('لا تدخل أي مفتاح سري هنا أو في المحادثة. ONESIGNAL_APP_ID و ONESIGNAL_REST_API_KEY يُحفظان في Supabase Edge Function Secrets فقط. / Never enter secret keys here or in chat; store them only in Supabase Edge Function Secrets.'),
      SwitchListTile(title:const Text('تفعيل النقل الخارجي / Enable external transport'),value:enabled,onChanged:busy?null:(v)=>setState(()=>enabled=v)),
      FilledButton(onPressed:busy?null:()=>action(false),child:const Text('حفظ / Save')),
      OutlinedButton(onPressed:busy?null:()=>action(true),child:const Text('إعادة محاولة غير المرسل خلال 24 ساعة / Retry unsent from last 24h')),
    ]);
  }));
}
