import 'auth_service.dart';
import 'account_page.dart';
import 'notifications_screen.dart';
import 'push_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'field_report_store.dart';
import 'field_report_form.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'operations_dashboard.dart';
import 'supabase_client.dart';

Future<ProfileAccess> fieldAccess() async {
  final user = supabaseClient.auth.currentUser!.id;
  final preferences = await SharedPreferences.getInstance();
  ProfileAccess account;
  try { account = await AuthService.profile(); }
  on AccessDenied { rethrow; }
  catch (_) {
    final cached = preferences.getString('field-profile-$user');
    if (cached == null) rethrow;
    account = ProfileAccess(Map<String, dynamic>.from(jsonDecode(cached) as Map));
    if (account.denial != null) throw AccessDenied(account.denial!);
    if(account.role!='technician')throw const AccessDenied('Offline access is for technician drafts only.');
    return account;
  }
  if (account.role == 'technician') await preferences.setString('field-profile-$user', jsonEncode(account.data));
  return account;
}

class TechnicianPage extends StatelessWidget {
  final bool english;
  const TechnicianPage({super.key,required this.english});
  @override
  Widget build(BuildContext context)=>AccountPage(english:english);
}

class TechnicianTasks extends StatefulWidget {
  final bool english;
  final String tenant;
  final String? visitId;
  const TechnicianTasks({super.key, required this.english, required this.tenant,this.visitId});
  @override
  State<TechnicianTasks> createState() => _TechnicianTasksState();
}
class _TechnicianTasksState extends State<TechnicianTasks> with WidgetsBindingObserver {
  late Future<List<Map<String, dynamic>>> data;
  RealtimeChannel? channel;
  Timer? timer, debounce;
  bool busy = false, offline = false;
  FieldReportStore? store;
  String tr(String ar, String en) => widget.english ? en : ar;
  @override
  void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this); data = load();
    channel = supabaseClient.channel('my-visits-${DateTime.now().microsecondsSinceEpoch}')
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'visits',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'technician_id', value: supabaseClient.auth.currentUser!.id),
        callback: (_) { debounce?.cancel(); debounce = Timer(const Duration(milliseconds: 350), refresh); })
      .subscribe((status, _) { if (status == RealtimeSubscribeStatus.subscribed) refresh(); });
    timer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
  }
  Future<List<Map<String, dynamic>>> load() async {
    store ??= await FieldReportStore.open(widget.tenant, supabaseClient.auth.currentUser!.id);
    try {
      final rows = <Map<String,dynamic>>[];
      for(var offset=0;;offset+=250){
        final page = await supabaseClient.rpc('get_my_field_visits',params:{'page_offset':offset}) as List;
        rows.addAll(page.map((r)=>Map<String,dynamic>.from(r as Map)));
        if(page.length<250)break;
      }
      await store!.writeJson('visits.json',rows);
      offline=false;
      return rows;
    } catch (_) {
      final cached=await store!.readJson('visits.json');
      if(cached==null)rethrow;
      offline=true;
      return List<Map<String,dynamic>>.from(cached as List);
    }
  }
  Future<void> external(Uri uri) async {
    try { if(!await launchUrl(uri,mode:LaunchMode.externalApplication))throw StateError('No app'); }
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(tr('تعذّر فتح التطبيق الخارجي','Could not open external app'))));}
  }
  void refresh() { if (mounted) setState(() => data = load()); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) refresh(); }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); timer?.cancel(); debounce?.cancel();
    final active = channel; if (active != null) supabaseClient.removeChannel(active);
    super.dispose();
  }
  Future<void> transition(Map<String, dynamic> row) async {
    if (row['status'] == 'in_progress') { await openReport(row); return; }
    const next = 'in_progress';
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(tr('تأكيد تحديث الزيارة', 'Confirm visit update')),
      content: Text(visitStatusLabel(next, widget.english)), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('إلغاء', 'Cancel'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('تأكيد', 'Confirm')))],
    ));
    if (confirmed != true || !mounted || busy) return;
    setState(() => busy = true);
    try {
      await supabaseClient.rpc('set_my_visit_state', params: {'visit_id': row['id'], 'next_state': next});
      row['status']='in_progress';
      final cached=await store!.readJson('visits.json') as List?;
      if(cached!=null){for(final item in cached){if(item['id']==row['id'])item['status']='in_progress';}await store!.writeJson('visits.json',cached);}
      await openReport(row); refresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('تعذّر التحديث. تحقق من التعيين والاتصال؛ لا تبدأ قبل الموعد.', 'Update failed. Check assignment and connection; do not start before scheduled time.'))));
    } finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> openReport(Map<String,dynamic> row) async {
    if(!mounted || store==null)return;
    await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>FieldReportForm(tenant:widget.tenant,user:supabaseClient.auth.currentUser!.id,visit:row['id'] as String,english:widget.english,store:store!)));
    refresh();
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(tr('زياراتي الميدانية', 'My field visits')), actions: [
    const NotificationBell(),
    IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)), IconButton(onPressed: () => PushService.signOut(scope: SignOutScope.local), icon: const Icon(Icons.logout)),
  ]), body: Column(children: [if (busy) const LinearProgressIndicator(), Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: data, builder: (context, snapshot) {
    if (snapshot.hasError) return Center(child: Text(tr('تعذّر التحميل. أعد المحاولة.', 'Load failed. Retry.')));
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
    if (snapshot.data!.isEmpty) return Center(child: Text(tr('لا توجد مهام مفتوحة', 'No open tasks')));
    return ListView(children: [
      if(offline) Padding(padding:const EdgeInsets.all(12),child:Text(tr('وضع دون اتصال: قائمة محفوظة قديمة. يمكنك متابعة مسودة زيارة بدأت سابقاً؛ بدء الزيارة والإرسال يحتاجان اتصالاً.', 'Offline: cached list may be stale. Continue a previously started report; starting/submitting needs internet.'))),
      for (final row in snapshot.data!.where((row)=>widget.visitId==null||row['id']==widget.visitId)) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${row['client_name']} / ${(row['site'] as Map?)?['name']} — ${visitStatusLabel(row['status'] as String, widget.english)}'),
      Text('${row['local_day'] == row['today'] ? tr('اليوم', 'Today') : row['status'] == 'in_progress' ? tr('قيد التنفيذ', 'In progress') : tr('قادمة', 'Upcoming')} — ${row['timezone']}'),
      Text(tr('الموعد التالي بتوقيت الجهاز:', 'Time below uses device timezone:')),
      Text('${row['scheduled_start'] == null ? tr('لم تُجدول', 'Unscheduled') : DateTime.parse(row['scheduled_start'] as String).toLocal()}'),
      SelectableText('${(row['site'] as Map?)?['address']}\n${(row['site'] as Map?)?['contact_phone'] ?? ''}\n${row['instructions'] ?? ''}'),
      Wrap(spacing:8,children:[
        OutlinedButton.icon(onPressed:(){final site=Map<String,dynamic>.from(row['site'] as Map); final query=site['latitude']!=null&&site['longitude']!=null?'${site['latitude']},${site['longitude']}':'${site['address']}';external(Uri.https('www.google.com','/maps/search/',{'api':'1','query':query}));},icon:const Icon(Icons.map),label:Text(tr('Google Maps','Google Maps'))),
        if((row['site'] as Map?)?['contact_phone']!=null)OutlinedButton.icon(onPressed:()=>external(Uri(scheme:'tel',path:(row['site'] as Map)['contact_phone'] as String)),icon:const Icon(Icons.phone),label:Text(tr('اتصال بمسؤول الموقع','Call site contact'))),
      ]),
      FilledButton(onPressed: busy || (row['status'] != 'in_progress' && (offline || row['scheduled_start'] == null || DateTime.parse(row['scheduled_start'] as String).isAfter(DateTime.now()))) ? null : () => transition(row),
        child: Text(row['status'] == 'in_progress' ? tr('فتح التقرير / متابعة المسودة', 'Open report / continue draft') : tr('بدء الزيارة', 'Start visit'))),
    ]))) ]);
  }))]));
}
