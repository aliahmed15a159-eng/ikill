import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'backend.dart';

class AdminPage extends StatelessWidget {
  final bool english;
  const AdminPage({super.key, required this.english});
  @override
  Widget build(BuildContext context) {
    if (!Backend.ready) return Scaffold(appBar: AppBar(title: const Text('Administration')),
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(english
        ? 'Configure native Firebase to use administration.' : 'يلزم إعداد Firebase الأصلي لاستخدام لوحة الإدارة.'))));
    return StreamBuilder<User?>(stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return snapshot.data == null ? AdminLogin(english: english) : AdminDashboard(english: english);
      });
  }
}

class AdminLogin extends StatefulWidget {
  final bool english;
  const AdminLogin({super.key, required this.english});
  @override
  State<AdminLogin> createState() => _AdminLoginState();
}
class _AdminLoginState extends State<AdminLogin> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  String tr(String ar, String en) => widget.english ? en : ar;
  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }
  Future<void> login() async {
    if (!(form.currentState?.validate() ?? false)) return;
    setState(() { busy = true; error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.text.trim(), password: password.text);
    } catch (_) {
      if (mounted) setState(() => error = tr('تعذّر تسجيل الدخول. تحقق من بياناتك والاتصال.', 'Sign-in failed. Check your credentials and connection.'));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(tr('دخول الإدارة', 'Administrator sign-in'))),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500), child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Form(key: form, child: Column(children: [
      const Icon(Icons.verified_user_outlined, size: 64), const SizedBox(height: 24),
      TextFormField(controller: email, enabled: !busy, keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.username], decoration: InputDecoration(labelText: tr('البريد الإلكتروني', 'Email')),
        validator: (v) => v == null || !v.contains('@') ? tr('أدخل البريد الإلكتروني', 'Enter email') : null),
      const SizedBox(height: 16),
      TextFormField(controller: password, enabled: !busy, obscureText: true, autofillHints: const [AutofillHints.password],
        decoration: InputDecoration(labelText: tr('كلمة المرور', 'Password')),
        validator: (v) => v == null || v.isEmpty ? tr('أدخل كلمة المرور', 'Enter password') : null),
      const SizedBox(height: 20),
      if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      FilledButton(onPressed: busy ? null : login, child: Text(busy ? '…' : tr('تسجيل الدخول', 'Sign in'))),
    ]))))),
  );
}

class AdminDashboard extends StatefulWidget {
  final bool english;
  const AdminDashboard({super.key, required this.english});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}
class _AdminDashboardState extends State<AdminDashboard> {
  String tr(String ar, String en) => widget.english ? en : ar;
  int tab = 0;
  String query = '';
  Future<void> action(Future<void> Function() fn) async {
    try { await fn(); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('فشلت العملية. تحقق من الاتصال والصلاحيات.', 'Operation failed. Check connection and permissions.')))); }
  }
  Future<void> delete(DocumentReference<Map<String, dynamic>> doc) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(tr('حذف نهائي؟', 'Permanently delete?')),
      content: Text(tr('لا يمكن التراجع عن الحذف.', 'This cannot be undone.')),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('إلغاء', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('حذف', 'Delete')))],
    ));
    if (confirmed == true) await action(() => doc.delete());
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('لوحة إدارة iKILL', 'iKILL administration')), actions: [
      IconButton(tooltip: tr('تغيير كلمة المرور', 'Change password'), onPressed: changePassword, icon: const Icon(Icons.lock_outline)),
      IconButton(tooltip: tr('خروج', 'Sign out'), onPressed: () => action(() => FirebaseAuth.instance.signOut()), icon: const Icon(Icons.logout)),
    ]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: DropdownButtonFormField<int>(value: tab,
        items: [tr('طلبات التواصل', 'Contact requests'), tr('الفروع', 'Branches'), tr('إعدادات الموقع', 'Site settings'), tr('الزيارات', 'Page views')]
          .asMap().entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: (v) => setState(() { tab = v ?? 0; query = ''; }))),
      if (tab == 0) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: TextField(
        decoration: InputDecoration(labelText: tr('بحث بالاسم أو الهاتف أو البريد', 'Search name, phone or email'), prefixIcon: const Icon(Icons.search)),
        onChanged: (v) => setState(() => query = v.toLowerCase()))),
      Expanded(child: tab == 2 ? settings() : records()),
    ]),
    floatingActionButton: tab == 1 ? FloatingActionButton(onPressed: () => editBranch(), child: const Icon(Icons.add)) : null,
  );

  Widget records() {
    final collection = tab == 0 ? 'contact_submissions' : tab == 1 ? 'branches' : 'page_views';
    Query<Map<String, dynamic>> request = Backend.db.collection(collection);
    if (tab != 1) request = request.orderBy('timestamp', descending: true);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: request.snapshots(), builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text(tr('تعذّر تحميل البيانات. تحقق من الصلاحيات والاتصال.', 'Cannot load data. Check permissions and connection.')));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final docs = snapshot.data!.docs.where((d) => query.isEmpty || d.data().values.join(' ').toLowerCase().contains(query)).toList();
      if (docs.isEmpty) return Center(child: Text(tr('لا توجد بيانات', 'No records')));
      return ListView.builder(padding: const EdgeInsets.all(12), itemCount: docs.length + 1, itemBuilder: (context, i) {
        if (i == 0) return Padding(padding: const EdgeInsets.all(12), child: Text('${tr('عدد السجلات', 'Records')}: ${docs.length}'));
        final doc = docs[i - 1], data = doc.data();
        return Card(child: ListTile(
          leading: Icon(tab == 1 ? Icons.apartment : tab == 0 ? Icons.mail_outline : Icons.analytics_outlined),
          title: Text('${data[tab == 1 ? (widget.english ? 'nameEn' : 'nameAr') : tab == 0 ? 'name' : 'page'] ?? doc.id}'),
          subtitle: Text('${data[tab == 1 ? 'status' : tab == 0 ? 'email' : 'timestamp'] ?? ''}'),
          trailing: IconButton(tooltip: tr('حذف', 'Delete'), icon: const Icon(Icons.delete_outline), onPressed: () => delete(doc.reference)),
          onTap: () => tab == 1 ? editBranch(doc) : showDetails(doc),
        ));
      });
    });
  }

  void showDetails(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true,
      builder: (context) => SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
        children: [for (final e in doc.data().entries) Padding(padding: const EdgeInsets.only(bottom: 16), child: SelectableText('${e.key}\n${e.value is Timestamp ? (e.value as Timestamp).toDate().toLocal() : e.value}'))],
      ))));
  }

  Future<void> editBranch([QueryDocumentSnapshot<Map<String, dynamic>>? doc]) async {
    final keys = ['nameAr', 'nameEn', 'countryAr', 'countryEn', 'phone'];
    final initial = doc?.data() ?? <String, dynamic>{};
    final values = await editFields(tr('بيانات الفرع', 'Branch details'), keys, initial, includeStatus: true);
    if (values == null) return;
    await action(() async {
      if (doc == null) {
        await Backend.db.collection('branches').add({...values, 'createdAt': FieldValue.serverTimestamp()});
      } else { await doc.reference.update(values); }
    });
  }

  Widget settings() => FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    future: Backend.db.collection('site_settings').doc('global').get(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text(tr('تعذّر تحميل الإعدادات', 'Cannot load settings')));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final data = snapshot.data!.data() ?? {};
      final keys = ['phone', 'emergency', 'address', for (var i = 1; i <= 4; i++) ...['stat${i}Value', 'stat${i}Label']];
      return ListView(padding: const EdgeInsets.all(20), children: [
        for (final key in keys) ListTile(title: Text(key), subtitle: Text('${data[key] ?? ''}')),
        FilledButton(onPressed: () async {
          final values = await editFields(tr('إعدادات الموقع', 'Site settings'), keys, data);
          if (values == null) return;
          await action(() => Backend.db.collection('site_settings').doc('global').set({
            ...values, 'email': 'info@ikill.net', 'stat1Value': '15', 'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)));
          if (mounted) setState(() {});
        }, child: Text(tr('تعديل الإعدادات', 'Edit settings'))),
      ]);
    });

  Future<Map<String, String>?> editFields(String title, List<String> keys, Map<String, dynamic> data, {bool includeStatus = false, Set<String> secret = const {}}) async {
    final controllers = {for (final key in keys) key: TextEditingController(text: '${data[key] ?? ''}')};
    var status = '${data['status'] ?? 'active'}';
    if (!['active', 'inactive'].contains(status)) status = 'inactive';
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<Map<String, String>>(context: context, builder: (context) => StatefulBuilder(builder: (context, update) => AlertDialog(
      title: Text(title), content: SizedBox(width: 500, child: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final key in keys) Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(
          controller: controllers[key], obscureText: secret.contains(key), decoration: InputDecoration(labelText: key),
          validator: (v) => key != 'phone' && (v?.trim().isEmpty ?? true) ? tr('مطلوب', 'Required') : null)),
        if (includeStatus) DropdownButtonFormField<String>(value: status,
          items: ['active', 'inactive'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (s) => update(() => status = s ?? status)),
      ])))) , actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('إلغاء', 'Cancel'))),
        FilledButton(onPressed: () {
          if (!(formKey.currentState?.validate() ?? false)) return;
          Navigator.pop(context, {for (final e in controllers.entries) e.key: secret.contains(e.key) ? e.value.text : e.value.text.trim(), if (includeStatus) 'status': status});
        }, child: Text(tr('حفظ', 'Save'))),
      ],
    )));
    // Controllers are kept until the dialog's reverse transition is complete.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    for (final c in controllers.values) { c.dispose(); }
    return result;
  }

  Future<void> changePassword() async {
    final values = await editFields(tr('تغيير كلمة المرور', 'Change password'), ['currentPassword', 'newPassword', 'confirmPassword'], {}, secret: {'currentPassword', 'newPassword', 'confirmPassword'});
    if (values == null) return;
    if (values['newPassword'] != values['confirmPassword'] || values['newPassword']!.length < 8) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('استخدم كلمة مرور متطابقة من 8 أحرف على الأقل.', 'Use matching passwords of at least 8 characters.'))));
      return;
    }
    await action(() async {
      final user = FirebaseAuth.instance.currentUser!;
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: values['currentPassword']!));
      await user.updatePassword(values['newPassword']!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('تم تغيير كلمة المرور', 'Password updated'))));
    });
  }
}
