import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin.dart';
import 'auth_service.dart';
import 'backend.dart';
import 'operations_dashboard.dart';
import 'supabase_client.dart';

class TechnicianPage extends StatelessWidget {
  final bool english;
  const TechnicianPage({super.key, required this.english});
  @override
  Widget build(BuildContext context) {
    if (!Backend.ready) return Scaffold(appBar: AppBar(title: Text(english ? 'Technician tasks' : 'مهام الفني')), body: const Center(child: Text('Configure Supabase')));
    return StreamBuilder<AuthState>(stream: supabaseClient.auth.onAuthStateChange, builder: (context, snapshot) {
      if (supabaseClient.auth.currentSession == null) return AdminLogin(english: english, technician: true);
      return FutureBuilder<ProfileAccess>(future: AuthService.profile(), builder: (context, profile) {
        if (profile.hasError || profile.hasData && profile.data!.role != 'technician') {
          return Scaffold(appBar: AppBar(title: Text(english ? 'Technician tasks' : 'مهام الفني')), body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(english ? 'An active technician account is required.' : 'يلزم حساب فني نشط؛ حساب الأدمن يستخدم لوحة الإدارة.'),
            TextButton(onPressed: () => supabaseClient.auth.signOut(scope: SignOutScope.local), child: Text(english ? 'Sign out' : 'خروج')),
          ])));
        }
        if (!profile.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return TechnicianTasks(key: ValueKey(supabaseClient.auth.currentUser!.id), english: english, tenant: profile.data!.tenantId);
      });
    });
  }
}
class TechnicianTasks extends StatefulWidget {
  final bool english;
  final String tenant;
  const TechnicianTasks({super.key, required this.english, required this.tenant});
  @override
  State<TechnicianTasks> createState() => _TechnicianTasksState();
}
class _TechnicianTasksState extends State<TechnicianTasks> with WidgetsBindingObserver {
  late Future<List<Map<String, dynamic>>> data;
  RealtimeChannel? channel;
  Timer? timer, debounce;
  bool busy = false;
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
    final account = await AuthService.profile();
    if (account.role != 'technician' || account.tenantId != widget.tenant) throw const AccessDenied('Technician required');
    return supabaseClient.from('visits').select('id,scheduled_start,scheduled_end,status,instructions,client_sites(name,address,contact_phone)')
      .eq('tenant_id', widget.tenant).eq('technician_id', supabaseClient.auth.currentUser!.id)
      .inFilter('status', ['scheduled','confirmed','in_progress']).order('scheduled_start').limit(500);
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
    final next = row['status'] == 'in_progress' ? 'completed' : 'in_progress';
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(tr('تأكيد تحديث الزيارة', 'Confirm visit update')),
      content: Text(visitStatusLabel(next, widget.english)), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('إلغاء', 'Cancel'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('تأكيد', 'Confirm')))],
    ));
    if (confirmed != true || !mounted || busy) return;
    setState(() => busy = true);
    try {
      await supabaseClient.rpc('set_my_visit_state', params: {'visit_id': row['id'], 'next_state': next}); refresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('تعذّر التحديث. تحقق من التعيين والاتصال؛ لا تبدأ قبل الموعد.', 'Update failed. Check assignment and connection; do not start before scheduled time.'))));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(tr('مهامي — توقيت الجهاز', 'My tasks — device time')), actions: [
    IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)), IconButton(onPressed: () => supabaseClient.auth.signOut(scope: SignOutScope.local), icon: const Icon(Icons.logout)),
  ]), body: Column(children: [if (busy) const LinearProgressIndicator(), Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: data, builder: (context, snapshot) {
    if (snapshot.hasError) return Center(child: Text(tr('تعذّر التحميل. أعد المحاولة.', 'Load failed. Retry.')));
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
    if (snapshot.data!.isEmpty) return Center(child: Text(tr('لا توجد مهام مفتوحة', 'No open tasks')));
    return ListView(children: [for (final row in snapshot.data!) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${(row['client_sites'] as Map?)?['name']} — ${visitStatusLabel(row['status'] as String, widget.english)}'),
      Text('${row['scheduled_start'] == null ? tr('لم تُجدول', 'Unscheduled') : DateTime.parse(row['scheduled_start'] as String).toLocal()}'),
      SelectableText('${(row['client_sites'] as Map?)?['address']}\n${(row['client_sites'] as Map?)?['contact_phone'] ?? ''}\n${row['instructions'] ?? ''}'),
      FilledButton(onPressed: busy || row['scheduled_start'] == null || DateTime.parse(row['scheduled_start'] as String).isAfter(DateTime.now()) ? null : () => transition(row),
        child: Text(row['status'] == 'in_progress' ? tr('إنهاء الزيارة', 'Complete visit') : tr('بدء الزيارة', 'Start visit'))),
    ]))) ]);
  }))]));
}
