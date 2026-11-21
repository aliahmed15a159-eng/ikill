import 'package:flutter/material.dart';
import 'request_repository.dart';
import 'request_models.dart';
import 'instapay_service.dart';
import 'content.dart';

class RequestForm extends StatefulWidget {
  final bool english;
  final RequestRepository repository;
  final SiteContent content;
  final String initialMessage,initialKind;
  final Map<String,String> initialContact;
  final VoidCallback onPrivacy;
  const RequestForm({super.key, required this.english, required this.content,
    required this.onPrivacy, this.initialMessage = '', this.initialKind='residential',this.initialContact=const {},this.repository = const RequestRepository()});
  @override
  State<RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<RequestForm> {
  final formKey = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{
    for (final key in ['name', 'phone', 'email', 'address', 'message', 'facility', 'payment_reference']) key: TextEditingController(),
  };
  RequestRepository get repository => widget.repository;
  String kind = 'residential', property = 'apartment', problem = 'cockroaches', sector = 'factory';
  ResidentialQuote? quote;
  InstapayDestination? destination;
  bool loadingQuote = false, paymentStep = false;
  String requestId = newRequestId();
  Map<String, dynamic>? retryPayload;

  Future<void> loadQuote() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() { loadingQuote = true; error = null; quote = null; });
    try {
      final result = await repository.quote(property, problem);
      final payment = result == null ? null : await repository.paymentDestination();
      if (!mounted) return;
      setState(() { quote = result; destination = payment; paymentStep = result != null && payment != null;
        if (result != null && payment == null) error = tr('الدفع بإنستا باي غير متاح حالياً حتى ترفع الإدارة كود QR وتفعّله. تواصل مع الإدارة.', 'InstaPay is unavailable until administration uploads and enables its QR code. Please contact administration.');
        if (result == null) error = tr('السعر غير متاح حالياً. تواصل مع الإدارة.', 'Price unavailable. Please contact administration.'); });
    } catch (_) {
      if (mounted) setState(() => error = tr('تعذّر تحميل السعر. أعد المحاولة.', 'Could not load price. Retry.'));
    } finally { if (mounted) setState(() => loadingQuote = false); }
  }
  bool sending = false, consent = false;
  String? error;
  String tr(String ar, String en) => widget.english ? en : ar;
  @override
  void initState() { super.initState(); fields['message']!.text = widget.initialMessage;kind=widget.initialKind=='contract'?'contract':'residential';for(final key in ['name','phone','email']){fields[key]!.text=widget.initialContact[key]??'';} }
  @override
  void dispose() { for (final c in fields.values) { c.dispose(); } super.dispose(); }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (!consent) { setState(() => error = tr('يرجى الموافقة على سياسة الخصوصية.', 'Please accept the privacy policy.')); return; }
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(tr('مراجعة وإرسال', 'Review and send')),
      content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        for (final key in fields.keys.where((k) => k != 'facility' && k != 'payment_reference' || k == 'facility' && kind == 'contract' || k == 'payment_reference' && paymentStep)) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('${widget.content.t('contact.form.$key', widget.english, key)}: ${fields[key]!.text.trim()}')),
        Text(kind == 'contract' ? tr('طلب معاينة بدون سعر ثابت', 'Survey request without fixed pricing') : '${quote?.amount} ${quote?.currency} — ${tr('تأكيد الدفع قيد المراجعة', 'Payment confirmation subject to review')}'),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('تعديل', 'Edit'))),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('إرسال الطلب', 'Send request')))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() { sending = true; error = null; });
    try {
      retryPayload ??= {
        for (final key in ['name', 'phone', 'email', 'address', 'message']) key: key == 'phone' ? normalizeDigits(fields[key]!.text) : fields[key]!.text.trim(),
        'kind': kind, 'consent': true,
        if (kind == 'residential') ...{
          'property': property, 'problem': problem, 'price_id': quote!.id,
          'expected_amount': quote!.amount, 'expected_currency': quote!.currency,
          'payment_reference': fields['payment_reference']!.text.trim(),
        } else ...{'facility': fields['facility']!.text.trim(), 'sector': sector},
      };
      await repository.submit(requestId, retryPayload!);
      if (!mounted) return;
      for (final c in fields.values) { c.clear(); }
      setState(() { consent = false; paymentStep = false; quote = null; retryPayload = null; requestId = newRequestId(); });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('تم تسجيل الطلب. التأكيد المالي والموعد بمعرفة الإدارة.', 'Request recorded. Payment and scheduling require administration review.'))));
    } catch (_) {
      if (mounted) {
        setState(() => error = tr(
        'تعذّر تأكيد الطلب. أعد المحاولة بنفس البيانات بأمان. إذا تغيّر السعر ابدأ طلباً جديداً.',
        'Could not confirm submission. Retry the same request safely. If the price changed, start a new request.'));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Widget choice(String value, Map<String, List<String>> options, String label, void Function(String) change) => Padding(
    padding: const EdgeInsets.only(bottom: 16), child: DropdownButtonFormField<String>(
      value: value, isExpanded: true, decoration: InputDecoration(labelText: label),
      items: options.keys.map((k) => DropdownMenuItem(value: k, child: Text(optionLabel(options, k, widget.english)))).toList(),
      onChanged: sending || loadingQuote || paymentStep || retryPayload != null ? null : (v) => setState(() => change(v!)),
    ));

  @override
  Widget build(BuildContext context) => Form(key: formKey, child: AutofillGroup(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text(tr('اطلب خدمة متخصصة', 'Request professional service'), style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 12),
    Text(tr('01 بيانات التواصل  •  02 تفاصيل الطلب  •  03 مراجعة وإرسال', '01 Contact details  •  02 Request details  •  03 Review and send')),
    const SizedBox(height: 24),
    choice(kind, const {'residential': ['خدمة سكنية لمرة واحدة', 'One-off residential service'], 'contract': ['تعاقد منشأة — طلب معاينة', 'Business contract — survey request']}, tr('نوع الخدمة', 'Service type'), (v) { kind = v; quote = null; paymentStep = false; }),
    for (final key in fields.keys.where((k) => k != 'facility' && k != 'payment_reference' || k == 'facility' && kind == 'contract' || k == 'payment_reference' && paymentStep)) Padding(padding: const EdgeInsets.only(bottom: 16), child: TextFormField(
      key: ValueKey(key), controller: fields[key], enabled: !sending && !loadingQuote && retryPayload == null && (!paymentStep || key == 'payment_reference'),
      maxLength: switch (key) { 'name' => 100, 'phone' => 20, 'email' => 150, 'address' => 200, 'facility' => 150, 'payment_reference' => 100, _ => 2000 },
      maxLines: key == 'message' ? 5 : 1,
      keyboardType: switch (key) { 'email' => TextInputType.emailAddress, 'phone' => TextInputType.phone, 'message' => TextInputType.multiline, _ => TextInputType.text },
      autofillHints: switch (key) { 'name' => [AutofillHints.name], 'email' => [AutofillHints.email], 'phone' => [AutofillHints.telephoneNumber], 'address' => [AutofillHints.streetAddressLine1], _ => null },
      decoration: InputDecoration(labelText: key == 'facility' ? tr('اسم المنشأة', 'Facility name') : key == 'payment_reference' ? tr('مرجع أو تفاصيل تأكيد الدفع', 'Payment reference or confirmation details') : widget.content.t('contact.form.$key', widget.english, key)),
      validator: (raw) {
        final value = key == 'phone' ? normalizeDigits(raw ?? '') : raw?.trim() ?? '';
        if (key == 'payment_reference' && value.length < 3) return tr('أدخل تأكيد الدفع (٣ أحرف على الأقل)', 'Enter payment confirmation (at least 3 characters)');
        if (key != 'message' && value.isEmpty) return tr('هذا الحقل مطلوب', 'This field is required');
        if (key == 'email' && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) return tr('أدخل بريداً إلكترونياً صحيحاً', 'Enter a valid email');
        if (key == 'phone' && value.isNotEmpty && !RegExp(r'^\+?[\d\s()\-]{7,20}$').hasMatch(value)) return tr('أدخل رقم هاتف صحيحاً', 'Enter a valid phone number');
        return null;
      },
    )),
    if (!paymentStep) ...[
      if (kind == 'residential') ...[
        choice(property, propertyOptions, tr('نوع العقار', 'Property type'), (v) => property = v),
        choice(problem, problemOptions, tr('نوع المشكلة', 'Pest problem'), (v) => problem = v),
      ] else ...[
        choice(sector, sectorOptions, tr('القطاع', 'Sector'), (v) => sector = v),
        Text(tr('طلب معاينة تلقائي بدون سعر ثابت. سنراجع موقع المنشأة وعنوانها للتواصل وتحديد المعاينة.', 'Automatic survey request without a fixed price. We will contact you to arrange the site survey.')),
      ],
    ],
    if (paymentStep) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      if (destination != null) ...[
        Text(tr('حوّل عبر إنستا باي إلى المستفيد:', 'Transfer via InstaPay to:')),
        SelectableText(destination!.beneficiary),
        Image.memory(destination!.image, height: 260, fit: BoxFit.contain, cacheWidth: 1024, errorBuilder: (_, __, ___) => Text(tr('تعذّر عرض QR. لا تحوّل قبل التحقق مع الإدارة.', 'QR cannot be displayed. Contact administration before transferring.'))),
        Text(tr('تحقق من اسم المستفيد داخل إنستا باي قبل التحويل. ', 'Check the beneficiary inside InstaPay before transferring.')),
      ],
      Text('${quote!.amount} ${quote!.currency}', style: Theme.of(context).textTheme.headlineSmall),
      Text(tr('تأكيد دفع فقط: لا توجد بوابة دفع إلكتروني. لا تدخل بيانات البطاقة أو رمز التحقق. أضف مرجع الدفع أو تفاصيل التأكيد المتفق عليها مع الإدارة؛ لن يُعتمد الدفع إلا بعد المراجعة.', 'Payment confirmation only: no online payment gateway. Never enter card details or OTPs. Enter the reference or confirmation agreed with administration; payment is not verified until reviewed.')),
      if (retryPayload == null) TextButton(onPressed: sending ? null : () => setState(() { paymentStep = false; quote = null; }), child: Text(tr('تعديل التفاصيل', 'Edit details'))),
    ]))),
    const SizedBox(height: 16),
    CheckboxListTile(contentPadding: EdgeInsets.zero, value: consent,
      onChanged: sending || retryPayload != null ? null : (v) => setState(() => consent = v ?? false),
      title: Text(tr('أوافق على استخدام بياناتي للتواصل بشأن طلبي.', 'I agree to the use of my details to respond to this request.'))),
    TextButton(onPressed: widget.onPrivacy, child: Text(tr('قراءة سياسة الخصوصية', 'Read privacy policy'))),
    if (error != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    if (retryPayload != null) TextButton(onPressed: sending ? null : () => setState(() { retryPayload = null; requestId = newRequestId(); paymentStep = false; quote = null; }), child: Text(tr('بدء طلب جديد (تحقق أولاً من عدم تسجيل السابق)', 'Start a new request (first check the previous one was not recorded)'))),
    FilledButton.icon(onPressed: sending || loadingQuote || !repository.ready ? null : kind == 'residential' && !paymentStep ? loadQuote : submit,
      icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_outlined),
      label: Text(sending ? tr('جاري الإرسال…', 'Sending…') : kind == 'residential' && !paymentStep ? tr('عرض السعر والمتابعة للدفع', 'Get price and continue to payment') : tr('مراجعة وإرسال', 'Review and send'))),
    if (!repository.ready) Padding(padding: const EdgeInsets.only(top: 12), child: Text(tr('الإرسال غير متاح حتى إعداد Supabase الأصلي للتطبيق. يمكنك الاتصال هاتفياً أو عبر البريد.', 'Submission is unavailable until native Supabase is configured. You can still call or email us.'))),
  ])));
}
