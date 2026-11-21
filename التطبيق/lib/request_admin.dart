import 'package:flutter/material.dart';
import 'request_models.dart';
import 'request_repository.dart';
import 'auth_service.dart';
import 'supabase_client.dart';

class RequestAdmin extends StatefulWidget {
  final bool english;
  final int mode;
  const RequestAdmin({super.key, required this.english, required this.mode});
  @override
  State<RequestAdmin> createState() => _RequestAdminState();
}

class _RequestAdminState extends State<RequestAdmin> {
  final repository = const RequestRepository();
  late Future<List<Map<String, dynamic>>> data;
  bool busy = false;
  String tr(String ar, String en) => widget.english ? en : ar;
  @override
  void initState() { super.initState(); reload(); }
  void reload() { data = widget.mode == 0 ? repository.prices() : repository.pending(widget.mode == 2); }
  Future<void> action(Future<void> Function() operation) async {
    setState(() => busy = true);
    try {
      await operation();
      if (mounted) setState(reload);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('تعذّرت العملية. تحقق من البيانات والاتصال والصلاحيات ثم حدّث القائمة.', 'Operation failed. Check data, connection and permissions, then refresh.'))));
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> editPrice(String property, String problem, Map<String, dynamic>? row) async {
    final controller = TextEditingController(text: row?['fixed_price']?.toString() ?? '');
    final form = GlobalKey<FormState>();
    var enabled = row?['is_active'] != false;
    final saved = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
      title: Text('${optionLabel(propertyOptions, property, widget.english)} / ${optionLabel(problemOptions, problem, widget.english)}'),
      content: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: tr('السعر بعملة الشركة', 'Price in company currency')),
          validator: (v) => validPriceInput(v ?? '') == null ? tr('أدخل سعراً موجباً بمنزلتين عشريتين كحد أقصى', 'Enter a positive price with at most two decimals') : null),
        SwitchListTile(title: Text(tr('متاح للطلب', 'Available to order')), value: enabled, onChanged: (v) => update(() => enabled = v)),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('إلغاء', 'Cancel'))),
        FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(ctx, true); }, child: Text(tr('حفظ', 'Save')))],
    )));
    final amount = validPriceInput(controller.text);
    controller.dispose();
    if (saved == true && amount != null) await action(() => repository.savePrice(property, problem, amount, enabled));
  }

  Future<void> schedule(Map<String, dynamic> row, bool survey) async {
    final technicians = await repository.technicians();
    if (!mounted) return;
    if (technicians.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('يلزم إضافة فني نشط أولاً.', 'Provision an active technician first.'))));
      return;
    }
    final date = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (time == null || !mounted) return;
    final start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    String technician = technicians.first['id'] as String;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr('تأكيد الجدولة', 'Confirm schedule')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${start.toLocal()} — ${tr('بتوقيت جهازك، المدة ساعة', 'device local time, one hour')}'),
        DropdownButtonFormField<String>(value: technician, isExpanded: true,
          items: technicians.map((t) => DropdownMenuItem(value: t['id'] as String, child: Text(t['full_name'] as String))).toList(), onChanged: (v) => technician = v!),
      ]), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('إلغاء', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('تأكيد', 'Confirm')))],
    ));
    if (confirmed != true) return;
    await action(() async {
      if (survey) {
        final account = await AuthService.requireAdmin();
        final result = await supabaseClient.from('surveys').update({'scheduled_at': start.toUtc().toIso8601String(), 'surveyor_id': technician, 'status': 'scheduled'})
          .eq('tenant_id', account.tenantId).eq('id', row['id']).eq('status', 'survey_pending').select('id');
        if (result.isEmpty) throw StateError('Request changed');
      } else {
        await repository.schedule(row['id'] as String, start, start.add(const Duration(hours: 1)), technician);
      }
    });
  }

  Future<void> review(Map<String, dynamic> row, bool approved) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr('مراجعة تأكيد الدفع', 'Review payment confirmation')),
      content: Text(approved ? tr('هل تحققت فعلياً من استلام المبلغ؟ هذا ليس تحققاً إلكترونياً.', 'Have you independently verified receipt of funds? This is not electronic verification.') : tr('رفض تأكيد الدفع؟ يلزم التواصل مع العميل.', 'Reject confirmation? Contact the customer to resolve it.')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('إلغاء', 'Cancel'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('تأكيد', 'Confirm')))],
    ));
    if (confirm == true) await action(() => repository.reviewPayment(row['id'] as String, approved));
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    TextButton.icon(onPressed: busy ? null : () => setState(reload), icon: const Icon(Icons.refresh), label: Text(tr('تحديث', 'Refresh'))),
    if (busy) const LinearProgressIndicator(),
    Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: data, builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text(tr('تعذّر التحميل. أعد المحاولة.', 'Could not load. Retry.')));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final rows = snapshot.data!;
      if (widget.mode == 0) return ListView(children: [
        Padding(padding: const EdgeInsets.all(16), child: Text(tr('الأسعار الفعلية فقط؛ لا يمكن الطلب حتى تفعيل السعر. لا تشمل هذه الشاشة أسعار العقود.', 'Set actual prices. Requests require an enabled price. Contract pricing is not included.'))),
        for (final property in propertyOptions.keys) for (final problem in problemOptions.keys)
          Builder(builder: (context) {
            final matches = rows.where((r) => r['property_type'] == property && r['problem_code'] == problem);
            final row = matches.isEmpty ? null : matches.first;
            return ListTile(title: Text('${optionLabel(propertyOptions, property, widget.english)} / ${optionLabel(problemOptions, problem, widget.english)}'),
              subtitle: Text(row == null ? tr('غير محدد', 'Not configured') : '${row['fixed_price']} ${row['currency']} — ${row['is_active'] == true ? tr('متاح', 'Enabled') : tr('معطل', 'Disabled')}'),
              trailing: const Icon(Icons.edit_outlined), onTap: busy ? null : () => editPrice(property, problem, row));
          }),
      ]);
      if (rows.isEmpty) return Center(child: Text(tr('لا توجد طلبات معلقة', 'No pending requests')));
      return ListView(children: [for (final row in rows) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SelectableText('${(row['clients'] as Map?)?['display_name'] ?? ''}\n${(row['clients'] as Map?)?['phone'] ?? ''}\n${(row['clients'] as Map?)?['email'] ?? ''}\n${(row['client_sites'] as Map?)?['address'] ?? ''}'),
        if (widget.mode == 1) ...[
          Text('${optionLabel(propertyOptions, row['property_type'] as String, widget.english)} / ${optionLabel(problemOptions, row['problem_code'] as String, widget.english)}'),
          SelectableText('${row['quoted_amount']} ${row['quoted_currency']}\n${row['payment_reference']}\n${row['payment_review']}\n${row['instructions'] ?? ''}'),
          if (row['payment_review'] == 'pending_review' || row['payment_review'] == 'rejected') Wrap(spacing: 8, children: [
            TextButton(onPressed: busy ? null : () => review(row, true), child: Text(tr('اعتماد بعد التحقق', 'Verify received funds'))),
            if (row['payment_review'] == 'pending_review') TextButton(onPressed: busy ? null : () => review(row, false), child: Text(tr('رفض', 'Reject'))),
          ]),
        ] else SelectableText('${row['assessment']}'),
        FilledButton(onPressed: busy || widget.mode == 1 && row['payment_review'] != 'verified' ? null : () => action(() => schedule(row, widget.mode == 2)), child: Text(tr('جدولة مع فني', 'Schedule with technician'))),
      ]))) ]);
    })),
  ]);
}
