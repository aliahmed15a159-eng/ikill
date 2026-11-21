import 'dart:async';
import 'package:flutter/material.dart';
import 'operations_repository.dart';
import 'lifecycle_forms.dart';

const visitColors = <String, Color>{'pending_schedule': Colors.grey, 'scheduled': Colors.blue,
  'confirmed': Colors.indigo, 'in_progress': Colors.orange, 'completed': Colors.green,
  'cancelled': Colors.red, 'no_access': Colors.brown};
String visitStatusLabel(String status, bool english) => {
  'pending_schedule': english ? 'Pending schedule' : 'بانتظار الجدولة', 'scheduled': english ? 'Scheduled' : 'مجدولة',
  'confirmed': english ? 'Confirmed' : 'مؤكدة', 'in_progress': english ? 'In progress' : 'قيد التنفيذ',
  'completed': english ? 'Completed' : 'مكتملة', 'cancelled': english ? 'Cancelled' : 'ملغاة',
  'no_access': english ? 'No access' : 'تعذّر الدخول',
}[status] ?? status;
DateTime calendarStart(DateTime month) {
  final first = DateTime(month.year, month.month);
  return DateTime(first.year, first.month, first.day - first.weekday + 1);
}

class OperationsDashboard extends StatefulWidget {
  final bool english;
  final OperationsRepository repository;
  const OperationsDashboard({super.key, required this.english, this.repository = const OperationsRepository()});
  @override
  State<OperationsDashboard> createState() => _OperationsDashboardState();
}
class _OperationsDashboardState extends State<OperationsDashboard> with WidgetsBindingObserver {
  Map<String, dynamic> summary = {}, metadata = {};
  List<Map<String, dynamic>> visits = [];
  DateTime selected = DateTime.now(), month = DateTime.now();
  String? client, site, technician, error, subscribedTenant;
  bool loading = true, busy = false, live = false, initialized = false, attaching = false;
  int generation = 0;
  Timer? debounce, fallback;
  OperationsSubscription? subscription;
  String tr(String ar, String en) => widget.english ? en : ar;
  List<Map<String, dynamic>> list(String key) => List<Map<String, dynamic>>.from(metadata[key] as List? ?? []);
  @override
  void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this); reload();
    fallback = Timer.periodic(const Duration(seconds: 60), (_) => reload());
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) reload(); }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); ++generation; debounce?.cancel(); fallback?.cancel();
    subscription?.close(); super.dispose();
  }
  void changed() { debounce?.cancel(); debounce = Timer(const Duration(milliseconds: 350), () { if (mounted) reload(); }); }
  Future<void> attach(String tenant) async {
    if (attaching || subscribedTenant == tenant) return;
    attaching = true;
    try {
      await subscription?.close();
      final handle = await widget.repository.watch(tenant, () { if (mounted) changed(); }, (connected) {
        if (!mounted) return;
        setState(() => live = connected);
        if (connected) changed(); // Refresh after reconnect to recover missed events.
      });
      if (!mounted) { await handle.close(); return; }
      subscription = handle; subscribedTenant = tenant;
    } catch (_) { if (mounted) setState(() => live = false); }
    finally { attaching = false; }
  }
  Future<void> reload() async {
    if (!mounted) return;
    final request = ++generation;
    setState(() { loading = true; error = null; });
    try {
      final results = await Future.wait([widget.repository.summary(), widget.repository.contextData()]);
      if (!mounted || request != generation) return;
      final stats = results[0], context = results[1];
      if (!initialized) { selected = DateTime.parse(stats['today'] as String); month = selected; initialized = true; }
      final clients = List<Map<String, dynamic>>.from(context['clients'] as List);
      final sites = List<Map<String, dynamic>>.from(context['sites'] as List);
      final technicians = List<Map<String, dynamic>>.from(context['technicians'] as List);
      if (client != null && !clients.any((c) => c['id'] == client)) client = null;
      if (site != null && !sites.any((s) => s['id'] == site && (client == null || s['client_id'] == client))) site = null;
      if (technician != null && !technicians.any((t) => t['id'] == technician)) technician = null;
      final first = calendarStart(month);
      final rows = await widget.repository.visits(first, DateTime(first.year, first.month, first.day + 42), client: client, site: site, technician: technician);
      if (!mounted || request != generation) return;
      setState(() { summary = stats; metadata = context; visits = rows; loading = false; });
      attach(context['tenant_id'] as String);
    } catch (_) {
      if (mounted && request == generation) setState(() { loading = false; error = tr('تعذّر التحديث. البيانات المعروضة قديمة؛ استخدم إعادة المحاولة.', 'Refresh failed. Displayed data may be stale; retry.'); });
    }
  }
  Future<void> assign(Map<String, dynamic>? visit) async {
    final bulk = visit == null;
    final selectedSite = site;
    if (bulk && selectedSite == null) return;
    final people = list('technicians').where((p) => p['is_active'] != false).toList();
    final matchedSites = list('sites').where((s) => s['id'] == selectedSite).toList();
    final String? initial = bulk
        ? (matchedSites.isEmpty ? null : matchedSites.first['default_technician_id'] as String?)
        : visit?['technician_id'] as String?;
    final result = await showDialog<String>(context: context, builder: (_) => TechnicianAssignmentDialog(english: widget.english,
      technicians: people, initial: initial, bulk: bulk));
    if (result == null || !mounted) return;
    setState(() => busy = true);
    try {
      final tech = result == '_none' ? null : result;
      if (bulk) {
        final count = await widget.repository.assignSite(selectedSite!, tech);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('تم تحديث الزيارات', 'Updated visits')}: $count')));
      } else {
        await widget.repository.assign(visit['id'] as String, tech);
      }
      await reload();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('تعذّر التعيين. يلزم فني نشط وزيارة مستقبلية لم تبدأ. حدّث القائمة وأعد المحاولة.', 'Assignment failed. Use an active technician and a future visit not yet started. Refresh and retry.'))));
    } finally { if (mounted) setState(() => busy = false); }
  }
  Widget filter(String label, String? value, List<Map<String, dynamic>> options, void Function(String?) update) => Padding(
    padding: const EdgeInsets.only(bottom: 8), child: DropdownButtonFormField<String>(value: value ?? '_all', isExpanded: true,
      decoration: InputDecoration(labelText: label), items: [DropdownMenuItem(value: '_all', child: Text(tr('الكل', 'All'))),
        for (final option in options) DropdownMenuItem(value: option['id'] as String, child: Text('${option['name']}', overflow: TextOverflow.ellipsis))],
      onChanged: busy ? null : (v) { setState(() => update(v == '_all' ? null : v)); reload(); }));
  void moveMonth(int offset) { setState(() { month = DateTime(month.year, month.month + offset); selected = month; }); reload(); }
  @override
  Widget build(BuildContext context) {
    final days = List.generate(42, (i) { final first = calendarStart(month); return DateTime(first.year, first.month, first.day + i); });
    final dayVisits = visits.where((v) => v['local_day'] == isoDay(selected)).toList();
    return RefreshIndicator(onRefresh: reload, child: ListView(padding: const EdgeInsets.all(12), children: [
      Text(tr('لوحة التشغيل والتقويم', 'Operations and calendar'), style: Theme.of(context).textTheme.titleLarge),
      Text('${summary['today'] ?? ''} — ${summary['timezone'] ?? ''}'),
      Row(children: [Icon(live ? Icons.wifi : Icons.sync_problem, color: live ? Colors.green : Colors.orange, size: 18), const SizedBox(width: 8),
        Expanded(child: Text(live ? tr('متصل بالتحديث الفوري', 'Realtime connected') : tr('التحديث الفوري غير متصل — تحديث احتياطي كل دقيقة', 'Realtime disconnected — one-minute fallback refresh'))),
        IconButton(tooltip: tr('تحديث', 'Refresh'), onPressed: busy ? null : reload, icon: const Icon(Icons.refresh))]),
      if (loading || busy) const LinearProgressIndicator(),
      if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in {'scheduled': tr('اليوم: مجدولة ومؤكدة', 'Today: scheduled/confirmed'), 'in_progress': tr('اليوم: قيد التنفيذ', 'Today: in progress'),
          'completed': tr('اليوم: مكتملة', 'Today: completed'), 'new_surveys': tr('معاينات جديدة', 'New surveys'), 'pending_schedule': tr('مرة واحدة: بانتظار الجدولة', 'One-off: pending schedule'),
          'active_contracts': tr('عقود نشطة وسارية', 'Active in-term contracts'), 'unpaid_invoices': tr('فواتير صادرة غير مسددة بالكامل', 'Issued unpaid/partial invoices')}.entries)
          SizedBox(width: 160, child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Text('${summary[e.key] ?? '—'}', style: Theme.of(context).textTheme.headlineSmall), Text(e.value, textAlign: TextAlign.center)])))),
      ]),
      const Divider(), Text(tr('الفلاتر تخص التقويم فقط؛ الإحصائيات لكل الشركة.', 'Filters apply to the calendar only; summary covers the company.')),
      filter(tr('العميل', 'Client'), client, list('clients'), (v) { client = v; site = null; }),
      filter(tr('الموقع / فرع العميل', 'Client site / branch'), site, list('sites').where((s) => client == null || s['client_id'] == client).toList(), (v) => site = v),
      filter(tr('الفني / المندوب', 'Technician / representative'), technician, list('technicians'), (v) => technician = v),
      OutlinedButton.icon(onPressed: busy || loading || site == null || !list('sites').any((s) => s['id'] == site && s['is_active'] != false) ? null : () => assign(null), icon: const Icon(Icons.groups_outlined),
        label: Text(tr('تعيين افتراضي وجماعي للموقع المختار', 'Set default and bulk-assign selected site'))),
      Text(tr('اختر موقعاً لتعيين كل زياراته المستقبلية وغير المجدولة التي لم تبدأ؛ يشمل استبدال الفني الحالي. لا يتغير الموعد أو اعتماد الدفع.', 'Choose a site to assign all future and unscheduled visits not yet started, replacing existing technicians. Times/payment review are unchanged.')),
      const SizedBox(height: 12),
      Row(children: [IconButton(tooltip: tr('الشهر السابق', 'Previous month'), onPressed: () => moveMonth(-1), icon: const Icon(Icons.chevron_left)),
        Expanded(child: Text('${month.year}-${month.month.toString().padLeft(2, '0')}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge)),
        IconButton(tooltip: tr('الشهر التالي', 'Next month'), onPressed: () => moveMonth(1), icon: const Icon(Icons.chevron_right)),
        TextButton(onPressed: () { final today = summary['today']; if (today != null) { setState(() { selected = DateTime.parse(today as String); month = selected; }); reload(); } }, child: Text(tr('اليوم', 'Today')))]),
      Row(children: [for (final name in widget.english ? ['Mo','Tu','We','Th','Fr','Sa','Su'] : ['إث','ثل','أر','خم','جم','سب','أح']) Expanded(child: Center(child: Text(name)))]),
      GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 0.8, children: [for (final day in days)
        Builder(builder: (_) {
          final rows = visits.where((v) => v['local_day'] == isoDay(day)).toList();
          final states = rows.map((v) => v['status'] as String).toSet();
          final chosen = isoDay(day) == isoDay(selected);
          return Semantics(label: '${isoDay(day)} — ${rows.length}', selected: chosen, button: true, child: InkWell(key: ValueKey('day-${isoDay(day)}'),
            onTap: () => setState(() => selected = day), child: Container(margin: const EdgeInsets.all(1), padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(border: Border.all(color: chosen ? Theme.of(context).colorScheme.primary : Colors.grey.withValues(alpha: 0.25)), borderRadius: BorderRadius.circular(6)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${day.day}', style: TextStyle(fontWeight: chosen ? FontWeight.bold : FontWeight.normal, color: day.month == month.month ? null : Colors.grey)),
                if (rows.isNotEmpty) Text('${rows.length}', style: const TextStyle(fontSize: 10)),
                Wrap(spacing: 1, runSpacing: 1, children: [for (final status in states) Container(width: 5, height: 5, color: visitColors[status] ?? Colors.grey)]),
              ]))));
        }),
      ]),
      Wrap(spacing: 10, runSpacing: 4, children: [for (final status in visitColors.keys) Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, size: 9, color: visitColors[status]), const SizedBox(width: 3), Text(visitStatusLabel(status, widget.english), style: const TextStyle(fontSize: 11))])]),
      const Divider(), Text('${tr('زيارات يوم', 'Visits on')} ${isoDay(selected)}', style: Theme.of(context).textTheme.titleLarge),
      Text(tr('الزيارات غير المجدولة تظهر في الإحصائية وقائمة انتظار الجدولة، وليس على يوم وهمي في التقويم.', 'Unscheduled visits appear in the summary/pending queue, not on an invented calendar date.')),
      if (dayVisits.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text(tr('لا توجد زيارات لهذا اليوم والفلاتر', 'No visits for this day and filters'))),
      for (final visit in dayVisits) Card(child: ListTile(isThreeLine: true,
        leading: Icon(Icons.circle, color: visitColors[visit['status']] ?? Colors.grey, size: 18),
        title: Text('${visit['local_time']} — ${visit['client_name']} / ${visit['site_name']}'),
        subtitle: Text('${visitStatusLabel(visit['status'] as String, widget.english)} — ${visit['contract_id'] == null ? tr('مرة واحدة', 'One-off') : tr('تعاقد', 'Contract')}\n${visit['technician_name'] ?? tr('بدون فني', 'Unassigned')}\n${visit['site_address'] ?? ''} — ${visit['site_contact_phone'] ?? ''}'),
        trailing: IconButton(tooltip: tr('تعيين الفني', 'Assign technician'), onPressed: busy || loading || !['scheduled','confirmed','pending_schedule'].contains(visit['status']) ? null : () => assign(visit), icon: const Icon(Icons.person_add_alt)),
      )),
    ]));
  }
}

class TechnicianAssignmentDialog extends StatefulWidget {
  final bool english, bulk;
  final List<Map<String, dynamic>> technicians;
  final String? initial;
  const TechnicianAssignmentDialog({super.key, required this.english, required this.technicians, required this.bulk, this.initial});
  @override
  State<TechnicianAssignmentDialog> createState() => _TechnicianAssignmentDialogState();
}
class _TechnicianAssignmentDialogState extends State<TechnicianAssignmentDialog> {
  late String selected = widget.technicians.any((t) => t['id'] == widget.initial) ? widget.initial! : '_none';
  String tr(String ar, String en) => widget.english ? en : ar;
  @override
  Widget build(BuildContext context) => AlertDialog(title: Text(tr('توزيع الفنيين', 'Technician assignment')),
    content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.bulk ? tr('سيُحفظ افتراضي للموقع وتُستبدل تعيينات كل الزيارات المستقبلية وغير المجدولة التي لم تبدأ. يطبّق أيضاً على الزيارات الجديدة للموقع. تأكد من ملاءمة مواعيد الفني؛ لا يوجد منع تلقائي لتعارض المواعيد.', 'Save site default and replace assignments on all future/unscheduled visits not yet started, including new visits. Check technician availability; schedule conflicts are not automatically prevented.') : tr('تغيير الفني فقط، دون تغيير الموعد أو حالة الدفع. تأكد من عدم تعارض المواعيد.', 'Changes technician only, not time or payment state. Check availability.')),
      DropdownButtonFormField<String>(value: selected, isExpanded: true, items: [DropdownMenuItem(value: '_none', child: Text(tr('إلغاء التعيين / بدون فني', 'Unassign / no technician'))),
        for (final t in widget.technicians) DropdownMenuItem(value: t['id'] as String, child: Text('${t['name']}'))], onChanged: (v) => setState(() => selected = v!)),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('إلغاء', 'Cancel'))), FilledButton(onPressed: () => Navigator.pop(context, selected), child: Text(tr('تأكيد التعيين', 'Confirm assignment')))],
  );
}
