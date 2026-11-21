import 'package:flutter/material.dart';
import 'client_repository.dart';
import 'lifecycle_forms.dart';
import 'request_models.dart';
import 'request_repository.dart';

class ClientAdmin extends StatefulWidget {
  final bool english;
  final ClientRepository repository;
  const ClientAdmin({super.key, required this.english, this.repository = const ClientRepository()});
  @override
  State<ClientAdmin> createState() => _ClientAdminState();
}
class _ClientAdminState extends State<ClientAdmin> {
  late Future<List<Map<String, dynamic>>> data;
  String query = '', pendingId = newRequestId();
  bool busy = false;
  Map<String, String> draft = {};
  String tr(String ar, String en) => widget.english ? en : ar;
  @override
  void initState() { super.initState(); data = widget.repository.clients(); }
  Future<void> add() async {
    final values = await showDialog<Map<String, String>>(context: context, builder: (_) => LifecycleEditor(english: widget.english,
      title: tr('إضافة عميل متعاقد', 'Add contract client'), initial: draft, fields: {
        'name': LifecycleField(tr('اسم العميل / المنشأة', 'Customer / facility name')),
        'contact': LifecycleField(tr('مسؤول التواصل', 'Contact person')),
        'phone': LifecycleField(tr('الهاتف', 'Phone'), 'phone'), 'email': LifecycleField(tr('البريد الإلكتروني', 'Email'), 'email'),
      }));
    if (values == null || !mounted) return;
    draft = values; setState(() => busy = true);
    try {
      await widget.repository.addClient(pendingId, values);
      if (!mounted) return;
      final id = pendingId; pendingId = newRequestId(); draft = {};
      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ClientDetail(english: widget.english, clientId: id, repository: widget.repository)));
      if (mounted) setState(() => data = widget.repository.clients());
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('تعذّر الحفظ. البيانات محفوظة لإعادة المحاولة.', 'Save failed. Reopen to retry your preserved details.'))));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(12), child: TextField(decoration: InputDecoration(labelText: tr('بحث العملاء', 'Search clients')), onChanged: (v) => setState(() => query = v.toLowerCase()))),
    Wrap(spacing: 12, children: [FilledButton.icon(onPressed: busy ? null : add, icon: const Icon(Icons.person_add_alt), label: Text(tr('إضافة عميل', 'Add client'))),
      TextButton(onPressed: busy ? null : () => setState(() => data = widget.repository.clients()), child: Text(tr('تحديث', 'Refresh')))]),
    if (busy) const LinearProgressIndicator(),
    Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: data, builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text(tr('تعذّر تحميل العملاء. أعد المحاولة.', 'Cannot load clients. Retry.')));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final rows = snapshot.data!.where((c) => c.values.join(' ').toLowerCase().contains(query)).toList();
      if (rows.isEmpty) return Center(child: Text(tr('لا يوجد عملاء', 'No clients')));
      return ListView(children: [for (final c in rows) ListTile(title: Text('${c['display_name']}'), subtitle: Text('${c['phone'] ?? ''} — ${c['client_type']} — ${c['status']}'),
        trailing: const Icon(Icons.chevron_left), onTap: () async {
          await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ClientDetail(english: widget.english, clientId: c['id'] as String, repository: widget.repository)));
          if (mounted) setState(() => data = widget.repository.clients());
        })]);
    })),
  ]);
}

class ClientDetail extends StatefulWidget {
  final bool english;
  final String clientId;
  final ClientRepository repository;
  const ClientDetail({super.key, required this.english, required this.clientId, this.repository = const ClientRepository()});
  @override
  State<ClientDetail> createState() => _ClientDetailState();
}
class _ClientDetailState extends State<ClientDetail> {
  late Future<Map<String, dynamic>> data;
  bool busy = false;
  final drafts = <String, Map<String, String>>{};
  String newContractId = newRequestId();
  final contractDrafts = <String, Map<String, dynamic>>{};
  String tr(String ar, String en) => widget.english ? en : ar;
  @override
  void initState() { super.initState(); reload(); }
  void reload() { data = widget.repository.detail(widget.clientId); }
  Future<void> action(Future<void> Function() operation) async {
    if (!mounted || busy) return;
    setState(() => busy = true);
    try { await operation(); if (mounted) setState(reload); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('تعذّرت العملية. تحقق من الاتصال والبيانات: معاينة مكتملة وسعر لكل موقع، بداية مستقبلية، وعدم تداخل العقود. لم يتم تفعيل عقد جزئي.', 'Operation failed. Check connection/data: completed priced site surveys, future start and no overlapping contract. No partial activation is committed.')))); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<Map<String, String>?> edit(String key, String title, Map<String, LifecycleField> fields, Map<String, String> initial) async {
    final result = await showDialog<Map<String, String>>(context: context, builder: (_) => LifecycleEditor(
      english: widget.english, title: title, fields: fields, initial: drafts[key] ?? initial));
    if (result != null) drafts[key] = result;
    return result;
  }
  Future<void> site([Map<String, dynamic>? row]) async {
    final id = row?['id'] as String? ?? 'new-site';
    final values = await edit(id, tr('بيانات الموقع', 'Site details'), {
      'name': LifecycleField(tr('اسم الفرع', 'Site name')), 'address': LifecycleField(tr('العنوان', 'Address')),
      'latitude': LifecycleField(tr('خط العرض', 'Latitude'), 'latitude'), 'longitude': LifecycleField(tr('خط الطول', 'Longitude'), 'longitude'),
      'sector': LifecycleField(tr('القطاع', 'Sector')), 'phone': LifecycleField(tr('رقم مسؤول الموقع', 'Site contact phone'), 'phone'),
    }, {'name': '${row?['name'] ?? ''}', 'address': '${row?['address'] ?? ''}', 'sector': '${row?['sector'] ?? ''}',
      'latitude': '${row?['latitude'] ?? ''}', 'longitude': '${row?['longitude'] ?? ''}', 'phone': '${row?['contact_phone'] ?? ''}'});
    if (values == null || !mounted) return;
    final siteId = row?['id'] as String? ?? drafts.putIfAbsent('site-identity', () => {'id': newRequestId()})['id']!;
    await action(() async { await widget.repository.saveSite(widget.clientId, siteId, values); drafts.remove(id); drafts.remove('site-identity'); });
  }
  Future<void> survey(Map<String, dynamic> site, Map<String, dynamic>? existing) async {
    final key = 'survey-${site['id']}';
    final assessment = existing?['assessment'] as Map? ?? {};
    final values = await edit(key, tr('تفاصيل المعاينة والأسعار', 'Survey details and pricing'), {
      'findings': LifecycleField(tr('نتائج المعاينة', 'Findings'), 'long'), 'details': LifecycleField(tr('تفاصيل الموقع والخدمات', 'Site and service details'), 'long'),
      'price': LifecycleField(tr('السعر المقترح لهذا الموقع', 'Proposed site price'), 'money'),
    }, {'findings': '${assessment['findings'] ?? ''}', 'details': '${assessment['site_details'] ?? ''}', 'price': '${existing?['proposed_total'] ?? ''}'});
    if (values == null || !mounted) return;
    final id = existing?['id'] as String? ?? drafts.putIfAbsent('$key-id', () => {'id': newRequestId()})['id']!;
    await action(() async { await widget.repository.saveSurvey(widget.clientId, site['id'] as String, id, values); drafts.remove(key); });
  }
  Future<void> contract(List<Map<String, dynamic>> sites, List<Map<String, dynamic>> plans, [Map<String, dynamic>? existing]) async {
    final id = existing?['id'] as String? ?? newContractId;
    final preserved = contractDrafts[id];
    final initial = preserved == null ? existing : {'starts_on': preserved['start'], 'ends_on': preserved['end'], 'billing_amount': preserved['total'], 'billing_cycle': preserved['cycle']};
    final initialPlans = preserved == null ? plans : List<Map<String, dynamic>>.from(preserved['plans'] as List);
    final values = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => ContractEditor(english: widget.english, sites: sites, initial: initial, plans: initialPlans));
    if (values == null || !mounted) return;
    contractDrafts[id] = values;
    await action(() async { await widget.repository.saveContract(id, widget.clientId, values); contractDrafts.remove(id); newContractId = newRequestId(); });
  }

  Future<void> activateContract(Map<String, dynamic> contract) async {
    final values = await edit('signature', tr('توقيع وتفعيل العقد', 'Sign and activate contract'), {
      'signer': LifecycleField(tr('اسم ممثل العميل الذي وقّع', 'Signing customer representative')),
      'reference': LifecycleField(tr('رقم/مرجع العقد الموقّع خارج التطبيق', 'Reference to externally signed agreement')),
    }, {});
    if (values == null || !mounted) return;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr('إقرار التوقيع والتفعيل', 'Confirm signature and activation')),
      content: Text(tr('أقرّ أن العقد موقّع فعلياً خارج التطبيق. سيُفعّل العميل وتُنشأ زيارات لكل المواقع الواردة بالعقد. هذه ليست خدمة توقيع إلكتروني أو تحصيل تلقائي. هل تؤكد؟', 'I confirm the agreement is signed externally. Activate the client and generate visits for the contracted sites? This is not an electronic-signature or payment service.')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('إلغاء', 'Cancel'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('توقيع وتفعيل العقد', 'Sign and activate contract')))],
    ));
    if (confirmed != true || !mounted) return;
    await action(() async {
      final count = await widget.repository.activate(contract['id'] as String, values['signer']!, values['reference']!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('تم التفعيل — الزيارات', 'Activated — visits')}: $count')));
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(tr('إدارة العميل ومواقعه', 'Client and sites')), actions: [IconButton(onPressed: busy ? null : () => setState(reload), icon: const Icon(Icons.refresh))]),
    body: Column(children: [if (busy) const LinearProgressIndicator(), Expanded(child: FutureBuilder<Map<String, dynamic>>(future: data, builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text(tr('تعذّر التحميل. استخدم التحديث.', 'Load failed. Use refresh.')));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final d = snapshot.data!, customer = d['client'] as Map<String, dynamic>;
      final sites = List<Map<String, dynamic>>.from(d['sites'] as List), surveys = List<Map<String, dynamic>>.from(d['surveys'] as List);
      final contracts = List<Map<String, dynamic>>.from(d['contracts'] as List), plans = List<Map<String, dynamic>>.from(d['plans'] as List);
      final activeSites = sites.where((s) => s['is_active'] == true).toList();
      return ListView(padding: const EdgeInsets.all(16), children: [
        Text('${customer['display_name']} — ${customer['status']}', style: Theme.of(context).textTheme.titleLarge),
        SelectableText('${customer['phone'] ?? ''}\n${customer['email'] ?? ''}'),
        if (customer['request_message'] != null) SelectableText('${tr('الطلب الأصلي', 'Original request')}: ${customer['request_message']}'),
        const Divider(), Text(tr('المواقع والفروع', 'Sites and branches'), style: Theme.of(context).textTheme.titleLarge),
        OutlinedButton.icon(onPressed: busy ? null : () => site(), icon: const Icon(Icons.add_location_alt_outlined), label: Text(tr('إضافة موقع', 'Add site'))),
        for (final s in sites) Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${s['name']} — ${s['sector']}'), SelectableText('${s['address']}\n${s['latitude'] ?? ''}, ${s['longitude'] ?? ''}\n${s['contact_phone'] ?? ''}'),
          TextButton(onPressed: busy ? null : () => site(s), child: Text(tr('تعديل الموقع', 'Edit site'))),
          Builder(builder: (_) {
            final matches = surveys.where((r) => r['site_id'] == s['id']);
            final latest = matches.isEmpty ? null : matches.first;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${tr('تفاصيل المعاينة', 'Survey details')}: ${latest?['status'] ?? '—'}'),
              if (latest != null) SelectableText('${latest['assessment']}\n${latest['proposed_total'] ?? ''} ${latest['currency']}'),
              TextButton(onPressed: busy ? null : () => survey(s, latest), child: Text(tr('تسجيل النتائج والأسعار', 'Record findings and price'))),
            ]);
          }),
        ]))),
        const Divider(), Text(tr('العقود', 'Contracts'), style: Theme.of(context).textTheme.titleLarge),
        if (customer['client_type'] == 'contract') FilledButton(onPressed: busy || activeSites.isEmpty ? null : () => contract(activeSites, []), child: Text(tr('إنشاء مسودة عقد لكل الفروع النشطة', 'New draft for all active sites'))),
        for (final c in contracts) Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SelectableText('${c['status']}\n${c['starts_on']} → ${c['ends_on']}\n${tr('إجمالي العقد', 'Total contract')}: ${c['billing_amount']} ${c['currency']} — ${c['billing_cycle']}'),
          for (final p in plans.where((p) => p['contract_id'] == c['id'])) Text('${sites.where((s) => s['id'] == p['site_id']).map((s) => s['name']).join()} — ${p['visits_per_month']} ${tr('زيارة / شهر', 'visits / month')}'),
          if (c['status'] == 'draft' && c['app_managed'] == true) ...[
            TextButton(onPressed: busy ? null : () => contract(activeSites, plans.where((p) => p['contract_id'] == c['id']).toList(), c), child: Text(tr('تعديل المسودة', 'Edit draft'))),
            FilledButton(onPressed: busy ? null : () => activateContract(c), child: Text(tr('توقيع وتفعيل العقد', 'Sign and activate contract'))),
          ],
          if (c['signed_at'] != null) SelectableText('${c['signed_by_name']} — ${c['signature_reference']}\n${c['signed_at']} — ${c['generated_visit_count']} ${tr('زيارة', 'visits')}'),
        ]))),
        OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ContractVisits(english: widget.english, clientId: widget.clientId, repository: widget.repository))), child: Text(tr('جدول الزيارات وتعديل المواعيد', 'Visit schedule and rescheduling'))),
      ]);
    }))]),
  );
}

class ContractVisits extends StatefulWidget {
  final bool english;
  final String clientId;
  final ClientRepository repository;
  const ContractVisits({super.key, required this.english, required this.clientId, required this.repository});
  @override
  State<ContractVisits> createState() => _ContractVisitsState();
}
class _ContractVisitsState extends State<ContractVisits> {
  late Future<List<Map<String, dynamic>>> data;
  int offset = 0;
  bool busy = false;
  String tr(String ar, String en) => widget.english ? en : ar;
  @override
  void initState() { super.initState(); reload(); }
  void reload() { data = widget.repository.visits(widget.clientId, offset); }
  Future<void> change(Map<String, dynamic> visit) async {
    setState(() => busy = true);
    try {
      final techs = await const RequestRepository().technicians();
      if (!mounted) return;
      final day = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 1100)));
      if (day == null || !mounted) return;
      final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
      if (time == null || !mounted) return;
      final start = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      String? technician = techs.any((t) => t['id'] == visit['technician_id']) ? visit['technician_id'] as String? : null;
      final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(tr('تعديل الموعد', 'Reschedule visit')),
        content: SizedBox(width: 350, child: Column(mainAxisSize: MainAxisSize.min, children: [Text('$start — ${tr('بتوقيت جهازك، ساعة واحدة', 'device timezone, one hour')}'),
          DropdownButtonFormField<String>(value: technician, isExpanded: true, items: [DropdownMenuItem(value: null, child: Text(tr('بدون فني حالياً', 'Unassigned'))),
            for (final t in techs) DropdownMenuItem(value: t['id'] as String, child: Text('${t['full_name']}'))], onChanged: (v) => technician = v),
        ])), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('إلغاء', 'Cancel'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('حفظ', 'Save')))],
      ));
      if (confirm != true) return;
      await widget.repository.reschedule(visit['id'] as String, start, start.add(const Duration(hours: 1)), technician);
      if (mounted) setState(reload);
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('تعذّر تعديل الموعد. يجب أن يكون مستقبلياً داخل مدة عقد نشط ولزيارة لم تبدأ.', 'Cannot reschedule. Choose a future time inside an active contract for a visit not yet started.')))); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(tr('جدول زيارات العميل', 'Client visit schedule'))),
    body: Column(children: [Text(tr('المواعيد أدناه بتوقيت جهازك. التوليد الأصلي بتوقيت الشركة.', 'Times below use device timezone. Generation uses company timezone.')),
      if (busy) const LinearProgressIndicator(),
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: data, builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text(tr('تعذّر التحميل', 'Load failed')));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!;
        return ListView(children: [for (final v in rows) ListTile(title: Text('${(v['client_sites'] as Map?)?['name']} — ${v['status']}'),
          subtitle: Text('${v['scheduled_start'] == null ? '' : DateTime.parse(v['scheduled_start'] as String).toLocal()}'),
          trailing: IconButton(onPressed: busy || !['scheduled','confirmed'].contains(v['status']) ? null : () => change(v), icon: const Icon(Icons.edit_calendar))),
          if (rows.isEmpty) ListTile(title: Text(tr('لا توجد زيارات في هذه الصفحة', 'No visits on this page'))),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [TextButton(onPressed: busy || offset == 0 ? null : () => setState(() { offset -= 100; reload(); }), child: Text(tr('السابق', 'Previous'))),
            Text('${offset ~/ 100 + 1}'), TextButton(onPressed: busy || rows.length < 100 ? null : () => setState(() { offset += 100; reload(); }), child: Text(tr('التالي', 'Next')))]),
        ]);
      })),
    ]),
  );
}
