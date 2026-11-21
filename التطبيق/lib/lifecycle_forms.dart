import 'package:flutter/material.dart';
import 'request_models.dart';

String isoDay(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String? validateLifecycleValue(String raw, String kind) {
  final value = normalizeDigits(raw);
  if (value.isEmpty) return 'مطلوب / Required';
  final number = num.tryParse(value);
  if (kind == 'money' && validPriceInput(value) == null) return 'سعر موجب بمنزلتين عشريتين / Positive amount, max 2 decimals';
  if (kind == 'latitude' && (number == null || !number.isFinite || number < -90 || number > 90)) return 'Latitude: -90 … 90';
  if (kind == 'longitude' && (number == null || !number.isFinite || number < -180 || number > 180)) return 'Longitude: -180 … 180';
  if (kind == 'date') {
    final day = DateTime.tryParse(value);
    if (day == null || isoDay(day) != value) return 'YYYY-MM-DD';
  }
  if (kind == 'phone' && !RegExp(r'^\+?[0-9 ()-]{7,30}$').hasMatch(value)) return 'رقم غير صحيح / Invalid phone';
  if (kind == 'email' && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) return 'بريد غير صحيح / Invalid email';
  return null;
}
class LifecycleField {
  final String label, kind;
  const LifecycleField(this.label, [this.kind = 'text']);
}
class LifecycleEditor extends StatefulWidget {
  final String title;
  final Map<String, LifecycleField> fields;
  final Map<String, String> initial;
  final bool english;
  const LifecycleEditor({super.key, required this.title, required this.fields, required this.english, this.initial = const {}});
  @override
  State<LifecycleEditor> createState() => _LifecycleEditorState();
}
class _LifecycleEditorState extends State<LifecycleEditor> {
  final form = GlobalKey<FormState>();
  late final controllers = {for (final key in widget.fields.keys) key: TextEditingController(text: widget.initial[key] ?? '')};
  @override
  void dispose() { for (final c in controllers.values) { c.dispose(); } super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(title: Text(widget.title),
    content: SizedBox(width: 500, child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      for (final field in widget.fields.entries) Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(
        controller: controllers[field.key], maxLength: field.value.kind == 'long' ? 2000 : 150,
        maxLines: field.value.kind == 'long' ? 3 : 1,
        keyboardType: ['money','latitude','longitude'].contains(field.value.kind) ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
        decoration: InputDecoration(labelText: field.value.label), validator: (v) => validateLifecycleValue(v ?? '', field.value.kind),
      )),
    ])))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.english ? 'Cancel' : 'إلغاء')),
      FilledButton(onPressed: () {
        if (!form.currentState!.validate()) return;
        Navigator.pop(context, {for (final field in widget.fields.entries) field.key:
          ['money','latitude','longitude','phone','date'].contains(field.value.kind) ? normalizeDigits(controllers[field.key]!.text) : controllers[field.key]!.text.trim()});
      }, child: Text(widget.english ? 'Save' : 'حفظ'))],
  );
}

class ContractEditor extends StatefulWidget {
  final bool english;
  final List<Map<String, dynamic>> sites, plans;
  final Map<String, dynamic>? initial;
  const ContractEditor({super.key, required this.english, required this.sites, this.initial, this.plans = const []});
  @override
  State<ContractEditor> createState() => _ContractEditorState();
}
class _ContractEditorState extends State<ContractEditor> {
  final form = GlobalKey<FormState>();
  late final start = TextEditingController(text: widget.initial?['starts_on'] as String? ?? isoDay(DateTime.now().add(const Duration(days: 1))));
  late final end = TextEditingController(text: widget.initial?['ends_on'] as String? ?? isoDay(DateTime.now().add(const Duration(days: 365))));
  late final total = TextEditingController(text: widget.initial?['billing_amount']?.toString() ?? '');
  late String cycle = widget.initial?['billing_cycle'] as String? ?? 'monthly';
  late final frequencies = {for (final site in widget.sites) site['id'] as String:
    widget.plans.where((p) => p['site_id'] == site['id']).map((p) => p['visits_per_month'] as int).firstOrNull ?? 1};
  String tr(String ar, String en) => widget.english ? en : ar;
  @override
  void dispose() { start.dispose(); end.dispose(); total.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(title: Text(tr('مسودة العقد', 'Contract draft')),
    content: SizedBox(width: 500, child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(tr('القيمة إجمالي العقد وتوزّع على دوراته مع ضبط فرق القروش في الدورة الأخيرة؛ فاتورة واحدة لكل دورة عند أول زيارة مكتملة. التوليد الساعة ١٠ صباحاً بتوقيت الشركة، لمدة ساعة. البداية من الغد؛ حد أقصى ٣٦ شهراً. لكل شهر جزئي نفس عدد الزيارات.', 'Total contract value is allocated across billing cycles, with final-cycle cent adjustment; one invoice per cycle on its first completed visit. Visits at 10 AM company time, one hour. Start tomorrow or later; under 36 months. Partial months receive the full monthly frequency.')),
      for (final entry in {start: tr('بداية العقد YYYY-MM-DD', 'Start YYYY-MM-DD'), end: tr('نهاية العقد YYYY-MM-DD', 'End YYYY-MM-DD'), total: tr('إجمالي قيمة العقد', 'Total contract value')}.entries)
        Padding(padding: const EdgeInsets.only(top: 12), child: TextFormField(controller: entry.key, decoration: InputDecoration(labelText: entry.value),
          validator: (v) {
            final invalid = validateLifecycleValue(v ?? '', entry.key == total ? 'money' : 'date');
            if (invalid != null) return invalid;
            if (entry.key == end && DateTime.parse(normalizeDigits(end.text)).isBefore(DateTime.tryParse(normalizeDigits(start.text)) ?? DateTime.now())) return tr('النهاية قبل البداية', 'End is before start');
            return null;
          })),
      DropdownButtonFormField<String>(isExpanded:true,value: cycle, decoration: InputDecoration(labelText: tr('نظام الفوترة', 'Billing cycle')),
        items: [for (final e in {'monthly': tr('شهري', 'Monthly'), 'quarterly': tr('ربع سنوي', 'Quarterly'), 'annual': tr('سنوي', 'Annual')}.entries) DropdownMenuItem(value: e.key, child: Text(e.value))], onChanged: (v) => setState(() => cycle = v!)),
      for (final site in widget.sites) DropdownButtonFormField<int>(value: frequencies[site['id']], isExpanded: true,
        decoration: InputDecoration(labelText: '${site['name']} — ${tr('زيارات شهرياً', 'visits/month')}'),
        items: [for (var i = 1; i <= 12; i++) DropdownMenuItem(value: i, child: Text('$i'))],
        onChanged: (v) => setState(() => frequencies[site['id'] as String] = v!)),
    ])))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('إلغاء', 'Cancel'))),
      FilledButton(onPressed: () {
        if (!form.currentState!.validate() || widget.sites.isEmpty) return;
        Navigator.pop(context, {'start': normalizeDigits(start.text), 'end': normalizeDigits(end.text), 'total': validPriceInput(total.text), 'cycle': cycle,
          'plans': [for (final e in frequencies.entries) {'site_id': e.key, 'visits_per_month': e.value}]});
      }, child: Text(tr('حفظ المسودة', 'Save draft')))],
  );
}
