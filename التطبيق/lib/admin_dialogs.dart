import 'package:flutter/material.dart';
import 'request_models.dart';

/// The route owns its Form and controllers until its exit animation finishes.
/// Never dispose a controller from the caller immediately after Navigator.pop.
class PriceEditor extends StatefulWidget {
  final bool english;
  final String property, problem;
  final Map<String, dynamic>? initial;
  const PriceEditor({super.key, required this.english, required this.property,
    required this.problem, this.initial});
  @override
  State<PriceEditor> createState() => _PriceEditorState();
}
class _PriceEditorState extends State<PriceEditor> {
  final form = GlobalKey<FormState>();
  late final amount = TextEditingController(text: widget.initial?['fixed_price']?.toString() ?? '');
  late bool enabled = widget.initial?['is_active'] != false;
  String tr(String ar, String en) => widget.english ? en : ar;
  @override
  void dispose() { amount.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${optionLabel(propertyOptions, widget.property, widget.english)} / ${optionLabel(problemOptions, widget.problem, widget.english)}'),
    content: SizedBox(width: 360, child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: amount, autofocus: true, maxLength: 13,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: tr('السعر بعملة الشركة', 'Price in company currency')),
        validator: (v) => validPriceInput(v ?? '') == null ? tr('أدخل سعراً موجباً بمنزلتين عشريتين كحد أقصى', 'Enter a positive price with at most two decimals') : null),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(tr('متاح للطلب', 'Available to order')),
        value: enabled, onChanged: (v) => setState(() => enabled = v)),
    ])))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('إلغاء', 'Cancel'))),
      FilledButton(onPressed: () {
        if (!form.currentState!.validate()) return;
        FocusScope.of(context).unfocus();
        Navigator.pop(context, {'amount': validPriceInput(amount.text)!, 'enabled': enabled});
      }, child: Text(tr('حفظ', 'Save')))],
  );
}

class AdminFieldsEditor extends StatefulWidget {
  final bool english, includeStatus;
  final String title;
  final List<String> fields;
  final Map<String, dynamic> initial;
  final Set<String> secret;
  const AdminFieldsEditor({super.key, required this.english, required this.title,
    required this.fields, required this.initial, this.includeStatus = false, this.secret = const {}});
  @override
  State<AdminFieldsEditor> createState() => _AdminFieldsEditorState();
}
class _AdminFieldsEditorState extends State<AdminFieldsEditor> {
  final form = GlobalKey<FormState>();
  late final controllers = {for (final key in widget.fields) key: TextEditingController(text: '${widget.initial[key] ?? ''}')};
  late String status = widget.initial['status'] == 'inactive' ? 'inactive' : 'active';
  String tr(String ar, String en) => widget.english ? en : ar;
  @override
  void dispose() { for (final c in controllers.values) { c.dispose(); } super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(title: Text(widget.title),
    content: SizedBox(width: 500, child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      for (final key in widget.fields) Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(
        key: ValueKey(key), controller: controllers[key], obscureText: widget.secret.contains(key),
        decoration: InputDecoration(labelText: key),
        validator: (v) => key != 'phone' && (v?.trim().isEmpty ?? true) ? tr('مطلوب', 'Required') : null)),
      if (widget.includeStatus) DropdownButtonFormField<String>(isExpanded:true,value: status,
        items: ['active', 'inactive'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (v) => setState(() => status = v!)),
    ])))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('إلغاء', 'Cancel'))),
      FilledButton(onPressed: () {
        if (!form.currentState!.validate()) return;
        FocusScope.of(context).unfocus();
        Navigator.pop(context, {for (final e in controllers.entries) e.key: widget.secret.contains(e.key) ? e.value.text : e.value.text.trim(),
          if (widget.includeStatus) 'status': status});
      }, child: Text(tr('حفظ', 'Save')))],
  );
}
