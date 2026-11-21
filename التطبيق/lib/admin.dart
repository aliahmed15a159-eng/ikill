import 'design/components.dart';
import 'account_page.dart';
import 'notifications_screen.dart';
import 'push_service.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'backend.dart';
import 'documents_screen.dart';
import 'portal_admin.dart';
import 'operations_dashboard.dart';
import 'client_admin.dart';
import 'admin_dialogs.dart';
import 'request_admin.dart';
import 'instapay_admin.dart';

class AdminPage extends StatelessWidget {
  final bool english;
  const AdminPage({super.key,required this.english});
  @override
  Widget build(BuildContext context)=>AccountPage(english:english);
}
// Compatibility entry point: all roles now use the same secure account router.
class AdminLogin extends StatelessWidget {
  final bool english,technician,client;
  const AdminLogin({super.key,required this.english,this.technician=false,this.client=false});
  @override
  Widget build(BuildContext context)=>AccountPage(english:english);
}

class AdminDashboard extends StatefulWidget {
  final bool english;
  const AdminDashboard({super.key, required this.english});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}
class _AdminDashboardState extends State<AdminDashboard> {
  String tr(String ar, String en) => widget.english ? en : ar;
  int tab = 8;
  String query = '';
  Future<void> action(Future<void> Function() fn) async {
    try { await fn(); if (mounted) setState(() {}); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('فشلت العملية. تحقق من الاتصال والصلاحيات.', 'Operation failed. Check connection and permissions.')))); }
  }
  Future<void> delete(Map<String, dynamic> doc) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(tr('حذف نهائي؟', 'Permanently delete?')),
      content: Text(tr('لا يمكن التراجع عن الحذف.', 'This cannot be undone.')),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('إلغاء', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('حذف', 'Delete')))],
    ));
    if (confirmed == true) await action(() => Backend.deleteRecord(tab, doc['id'] as String));
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('لوحة إدارة iKILL', 'iKILL administration')), actions: [
      const NotificationBell(),
      IconButton(tooltip: tr('تغيير كلمة المرور', 'Change password'), onPressed: changePassword, icon: const Icon(Icons.lock_outline)),
      IconButton(tooltip: tr('خروج', 'Sign out'), onPressed: () => action(() => PushService.signOut()), icon: const Icon(Icons.logout)),
    ]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: DropdownButtonFormField<int>(value: tab,
        items: [tr('إدارة العملاء', 'Client management'), tr('الفروع', 'Branches'), tr('إعدادات الموقع', 'Site settings'), tr('الزيارات', 'Page views'), tr('أسعار الخدمات السكنية', 'Residential prices'), tr('طلبات بانتظار الجدولة', 'Pending scheduling'), tr('طلبات معاينة المنشآت', 'Business survey requests'), tr('إعداد QR إنستا باي', 'InstaPay QR settings'), tr('لوحة التشغيل والتقويم', 'Operations and calendar'), tr('التقارير والفواتير والتحصيل', 'Documents and collection'), tr('هوية الشركة للمستندات', 'Document branding')]
          .asMap().entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: (v) => setState(() { tab = v ?? 0; query = ''; }))),
      Expanded(child: tab == 10 ? DocumentBrandSettings(english: widget.english) : tab == 9 ? DocumentsScreen(english: widget.english) : tab == 8 ? OperationsDashboard(english: widget.english) : tab == 0 ? ClientAdmin(english: widget.english) : tab == 7 ? InstapayAdmin(english: widget.english) : tab >= 4 ? RequestAdmin(key: ValueKey(tab), english: widget.english, mode: tab - 4) : tab == 2 ? settings() : records()),
    ]),
    floatingActionButton: tab == 1 ? FloatingActionButton(onPressed: () => editBranch(), child: const Icon(Icons.add)) : null,
  );

  Widget records() {
    return FutureBuilder<List<Map<String, dynamic>>>(future: Backend.records(tab), builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text(tr('تعذّر تحميل البيانات. تحقق من الصلاحيات والاتصال.', 'Cannot load data. Check permissions and connection.')));
      if (!snapshot.hasData) return const SkeletonLoader();
      final docs = snapshot.data!.where((d) => query.isEmpty || d.values.join(' ').toLowerCase().contains(query)).toList();
      if (docs.isEmpty) return Center(child: Text(tr('لا توجد بيانات', 'No records')));
      return ListView.builder(padding: const EdgeInsets.all(12), itemCount: docs.length + 1, itemBuilder: (context, i) {
        if (i == 0) return Padding(padding: const EdgeInsets.all(12), child: Text('${tr('عدد السجلات', 'Records')}: ${docs.length}'));
        final doc = docs[i - 1], data = doc;
        return Card(child: ListTile(
          leading: Icon(tab == 1 ? Icons.apartment : tab == 0 ? Icons.mail_outline : Icons.analytics_outlined),
          title: Text('${data[tab == 1 ? (widget.english ? 'nameEn' : 'nameAr') : tab == 0 ? 'name' : 'page'] ?? doc['id']}'),
          subtitle: Text('${data[tab == 1 ? 'status' : tab == 0 ? 'email' : 'timestamp'] ?? ''}'),
          trailing: IconButton(tooltip: tr('حذف', 'Delete'), icon: const Icon(Icons.delete_outline), onPressed: () => delete(doc)),
          onTap: () => tab == 1 ? editBranch(doc) : showDetails(doc),
        ));
      });
    });
  }

  void showDetails(Map<String, dynamic> doc) {
    showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true,
      builder: (context) => SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
        children: [for (final e in doc.entries) Padding(padding: const EdgeInsets.only(bottom: 16), child: SelectableText('${e.key}\n${e.value}'))],
      ))));
  }

  Future<void> editBranch([Map<String, dynamic>? doc]) async {
    final keys = ['nameAr', 'nameEn', 'countryAr', 'countryEn', 'phone'];
    final initial = doc ?? <String, dynamic>{};
    final values = await editFields(tr('بيانات الفرع', 'Branch details'), keys, initial, includeStatus: true);
    if (values == null || !mounted) return;
    await action(() => Backend.saveBranch(values, id: doc?['id'] as String?));
  }

  Widget settings() => FutureBuilder<Map<String, dynamic>>(
    future: Backend.adminSettings(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text(tr('تعذّر تحميل الإعدادات', 'Cannot load settings')));
      if (!snapshot.hasData) return const SkeletonLoader();
      final data = snapshot.data!;
      final keys = ['phone', 'emergency', 'address', for (var i = 1; i <= 4; i++) ...['stat${i}Value', 'stat${i}Label']];
      return ListView(padding: const EdgeInsets.all(20), children: [
        for (final key in keys) ListTile(title: Text(key), subtitle: Text('${data[key] ?? ''}')),
        FilledButton(onPressed: () async {
          final values = await editFields(tr('إعدادات الموقع', 'Site settings'), keys, data);
          if (values == null || !mounted) return;
          await action(() => Backend.saveSettings(values));
          if (mounted) setState(() {});
        }, child: Text(tr('تعديل الإعدادات', 'Edit settings'))),
      ]);
    });

  Future<Map<String, String>?> editFields(String title, List<String> keys, Map<String, dynamic> data, {bool includeStatus = false, Set<String> secret = const {}}) async {
    return showDialog<Map<String, String>>(context: context, builder: (_) => AdminFieldsEditor(
      english: widget.english, title: title, fields: keys, initial: data, includeStatus: includeStatus, secret: secret));
  }

  Future<void> changePassword() async {
    final values = await editFields(tr('تغيير كلمة المرور', 'Change password'), ['currentPassword', 'newPassword', 'confirmPassword'], {}, secret: {'currentPassword', 'newPassword', 'confirmPassword'});
    if (values == null || !mounted) return;
    if (values['newPassword'] != values['confirmPassword'] || values['newPassword']!.length < 8) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('استخدم كلمة مرور متطابقة من 8 أحرف على الأقل.', 'Use matching passwords of at least 8 characters.'))));
      return;
    }
    await action(() async {
      await AuthService.changePassword(values['currentPassword']!, values['newPassword']!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('تم تغيير كلمة المرور', 'Password updated'))));
    });
  }
}
