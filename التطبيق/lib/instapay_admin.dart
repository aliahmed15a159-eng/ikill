import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'instapay_service.dart';

class InstapayAdmin extends StatefulWidget {
  final bool english;
  const InstapayAdmin({super.key, required this.english});
  @override
  State<InstapayAdmin> createState() => _InstapayAdminState();
}

class _InstapayAdminState extends State<InstapayAdmin> {
  final beneficiary = TextEditingController();
  final form = GlobalKey<FormState>();
  String? path, error;
  Uint8List? image;
  bool busy = true, enabled = false, loaded = false, dirty = false;
  String tr(String ar, String en) => widget.english ? en : ar;
  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { beneficiary.dispose(); super.dispose(); }

  Future<void> load() async {
    setState(() { busy = true; error = null; });
    try {
      final row = await InstapayService.adminSettings();
      final storedPath = row?['qr_path'] as String?;
      final bytes = storedPath == null ? null : await InstapayService.preview(storedPath);
      if (!mounted) return;
      setState(() {
        path = storedPath; image = bytes; beneficiary.text = row?['beneficiary_name'] as String? ?? '';
        enabled = row?['enabled'] == true; loaded = true; dirty = false;
      });
    } catch (_) {
      if (mounted) setState(() => error = tr('تعذّر تحميل الإعدادات. أعد المحاولة.', 'Could not load settings. Retry.'));
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> pick() async {
    setState(() { busy = true; error = null; });
    try {
      final selected = await ImagePicker().pickImage(source: ImageSource.gallery, requestFullMetadata: false);
      if (selected == null) return;
      if (await selected.length() > 5 * 1024 * 1024) throw ArgumentError('Too large');
      final bytes = await selected.readAsBytes();
      if (InstapayService.imageType(bytes) == null) throw ArgumentError('Invalid image');
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1024);
      final frame = await codec.getNextFrame();
      frame.image.dispose(); codec.dispose();
      if (mounted) setState(() { image = bytes; dirty = true; });
    } catch (_) {
      if (mounted) setState(() => error = tr('اختر صورة QR واضحة بصيغة PNG أو JPEG بحجم لا يتجاوز ٥ ميجابايت.', 'Choose a clear QR PNG or JPEG image, at most 5 MB.'));
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (enabled && image == null) {
      setState(() => error = tr('ارفع صورة QR قبل التفعيل.', 'Upload a QR image before enabling.'));
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      // Uploads use new paths; replacing a QR never overwrites a published image.
      // Keep the uploaded path if saving fails so retry does not upload again.
      if (dirty && image != null) {
        path = await InstapayService.upload(image!);
        dirty = false;
      }
      await InstapayService.save(path, beneficiary.text, enabled);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('تم حفظ إعدادات إنستا باي.', 'InstaPay settings saved.'))));
    } catch (_) {
      if (mounted) setState(() => error = tr('تعذّر الحفظ. تحقق من الاتصال والصلاحيات وأعد المحاولة.', 'Could not save. Check connection and permissions, then retry.'));
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(padding: const EdgeInsets.all(20), child: Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text(tr('إعداد QR إنستا باي', 'InstaPay QR settings'), style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 12),
    Text(tr('ارفع صورة QR الأصلية من حساب الاستلام. تحقق بنفسك من أن الكود واسم المستفيد صحيحان قبل التفعيل. التطبيق لا يولّد بيانات حساب ولا يتحقق من وجهة الكود تلقائياً.', 'Upload the original QR image from the receiving account. Independently check the QR and beneficiary before enabling. The app does not generate account details or automatically verify the QR destination.')),
    if (busy) const LinearProgressIndicator(),
    if (image != null) Padding(padding: const EdgeInsets.all(16), child: Image.memory(image!, height: 260, fit: BoxFit.contain, cacheWidth: 1024, errorBuilder: (_, __, ___) => Text(tr('تعذّر عرض الصورة', 'Image could not be displayed')))),
    if (image == null && loaded) Padding(padding: const EdgeInsets.all(16), child: Text(tr('لم تتم إضافة QR بعد. الدفع غير متاح للعملاء حتى رفعه وتفعيله.', 'No QR added. Payment is unavailable to customers until uploaded and enabled.'))),
    OutlinedButton.icon(onPressed: busy || !loaded ? null : pick, icon: const Icon(Icons.upload_outlined), label: Text(tr('رفع أو استبدال صورة QR', 'Upload or replace QR image'))),
    const SizedBox(height: 16),
    TextFormField(controller: beneficiary, enabled: !busy && loaded, maxLength: 150,
      decoration: InputDecoration(labelText: tr('اسم المستفيد الظاهر عند التحويل', 'Beneficiary name shown on transfer')),
      validator: (v) => enabled && (v?.trim().isEmpty ?? true) ? tr('أدخل اسم المستفيد', 'Enter beneficiary name') : null),
    SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(tr('إظهار QR للعملاء وتفعيل الدفع', 'Show QR to customers and enable payment')),
      value: enabled, onChanged: busy || !loaded ? null : (v) => setState(() => enabled = v)),
    if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    const SizedBox(height: 12),
    FilledButton(onPressed: busy || !loaded ? null : save, child: Text(tr('حفظ ونشر الإعدادات', 'Save and publish settings'))),
    TextButton(onPressed: busy ? null : load, child: Text(tr('إعادة تحميل المحفوظ (إلغاء التعديلات)', 'Reload saved settings (discard changes)'))),
  ])));
}
