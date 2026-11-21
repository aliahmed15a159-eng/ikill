import 'package:flutter/material.dart';
import 'backend.dart';
import 'content.dart';

class RequestForm extends StatefulWidget {
  final bool english;
  final SiteContent content;
  final String initialMessage;
  final VoidCallback onPrivacy;
  const RequestForm({super.key, required this.english, required this.content,
    required this.onPrivacy, this.initialMessage = ''});
  @override
  State<RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<RequestForm> {
  final formKey = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{
    for (final key in ['name', 'phone', 'email', 'address', 'message']) key: TextEditingController(),
  };
  String service = 'مكافحة الآفات';
  bool sending = false, consent = false;
  String? error;
  String tr(String ar, String en) => widget.english ? en : ar;
  @override
  void initState() { super.initState(); fields['message']!.text = widget.initialMessage; }
  @override
  void dispose() { for (final c in fields.values) { c.dispose(); } super.dispose(); }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (!consent) { setState(() => error = tr('يرجى الموافقة على سياسة الخصوصية.', 'Please accept the privacy policy.')); return; }
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(tr('مراجعة وإرسال', 'Review and send')),
      content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        for (final key in fields.keys) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('${widget.content.t('contact.form.$key', widget.english, key)}: ${fields[key]!.text.trim()}')),
        Text(widget.content.translate(service, widget.english)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('تعديل', 'Edit'))),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('إرسال الطلب', 'Send request')))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() { sending = true; error = null; });
    try {
      await Backend.submit({for (final e in fields.entries) e.key: e.value.text.trim(), 'service': service});
      if (!mounted) return;
      for (final c in fields.values) { c.clear(); }
      setState(() { consent = false; service = 'مكافحة الآفات'; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('تم إرسال طلبك بنجاح. سنتواصل معك قريباً.', 'Your request has been sent. We will contact you soon.'))));
    } catch (_) {
      if (mounted) setState(() => error = tr(
        'تعذّر تأكيد إرسال الطلب. تحقق من اتصالك وإعداد Firebase. بياناتك محفوظة في النموذج؛ تحقق قبل إعادة الإرسال لتفادي التكرار.',
        'Could not confirm submission. Check your connection and Firebase configuration. Your form is preserved; check before retrying to avoid duplicates.'));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(key: formKey, child: AutofillGroup(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text(tr('اطلب خدمة متخصصة', 'Request professional service'), style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 12),
    Text(tr('01 بيانات التواصل  •  02 تفاصيل الطلب  •  03 مراجعة وإرسال', '01 Contact details  •  02 Request details  •  03 Review and send')),
    const SizedBox(height: 24),
    for (final key in fields.keys) Padding(padding: const EdgeInsets.only(bottom: 16), child: TextFormField(
      controller: fields[key], enabled: !sending,
      maxLength: switch (key) { 'name' => 100, 'phone' => 20, 'email' => 150, 'address' => 200, _ => 2000 },
      maxLines: key == 'message' ? 5 : 1,
      keyboardType: switch (key) { 'email' => TextInputType.emailAddress, 'phone' => TextInputType.phone, 'message' => TextInputType.multiline, _ => TextInputType.text },
      autofillHints: switch (key) { 'name' => [AutofillHints.name], 'email' => [AutofillHints.email], 'phone' => [AutofillHints.telephoneNumber], 'address' => [AutofillHints.streetAddressLine1], _ => null },
      decoration: InputDecoration(labelText: widget.content.t('contact.form.$key', widget.english, key)),
      validator: (raw) {
        final value = raw?.trim() ?? '';
        if (key != 'phone' && value.isEmpty) return tr('هذا الحقل مطلوب', 'This field is required');
        if (key == 'email' && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) return tr('أدخل بريداً إلكترونياً صحيحاً', 'Enter a valid email');
        if (key == 'phone' && value.isNotEmpty && !RegExp(r'^\+?[\d\s()\-]{7,20}$').hasMatch(value)) return tr('أدخل رقم هاتف صحيحاً', 'Enter a valid phone number');
        return null;
      },
    )),
    DropdownButtonFormField<String>(value: service, isExpanded: true,
      decoration: InputDecoration(labelText: tr('نوع الخدمة', 'Service')),
      items: ['مكافحة الآفات', 'خدمة مخصصة'].map((s) => DropdownMenuItem(value: s, child: Text(widget.content.translate(s, widget.english)))).toList(),
      onChanged: sending ? null : (s) => setState(() => service = s ?? service)),
    const SizedBox(height: 16),
    CheckboxListTile(contentPadding: EdgeInsets.zero, value: consent,
      onChanged: sending ? null : (v) => setState(() => consent = v ?? false),
      title: Text(tr('أوافق على استخدام بياناتي للتواصل بشأن طلبي.', 'I agree to the use of my details to respond to this request.'))),
    TextButton(onPressed: widget.onPrivacy, child: Text(tr('قراءة سياسة الخصوصية', 'Read privacy policy'))),
    if (error != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    FilledButton.icon(onPressed: sending || !Backend.ready ? null : submit,
      icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_outlined),
      label: Text(sending ? tr('جاري الإرسال…', 'Sending…') : tr('مراجعة وإرسال', 'Review and send'))),
    if (!Backend.ready) Padding(padding: const EdgeInsets.only(top: 12), child: Text(tr('الإرسال غير متاح حتى إعداد Firebase الأصلي للتطبيق. يمكنك الاتصال هاتفياً أو عبر البريد.', 'Submission is unavailable until native Firebase is configured. You can still call or email us.'))),
  ])));
}
