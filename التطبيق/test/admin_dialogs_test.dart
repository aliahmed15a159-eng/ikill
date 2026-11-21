import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikill_native/admin_dialogs.dart';
import 'package:ikill_native/request_admin.dart';
import 'package:ikill_native/request_repository.dart';

class MemoryRequests extends RequestRepository {
  final rows = <Map<String, dynamic>>[];
  bool failSave = false;
  int saves = 0;
  @override
  Future<List<Map<String, dynamic>>> prices() async => rows;
  @override
  Future<void> savePrice(String property, String problem, String amount, bool enabled) async {
    if (failSave) throw StateError('network');
    saves++;
    rows.removeWhere((r) => r['property_type'] == property && r['problem_code'] == problem);
    rows.add({'property_type': property, 'problem_code': problem, 'fixed_price': amount, 'is_active': enabled, 'currency': 'EGP'});
  }
  @override
  Future<List<Map<String, dynamic>>> pending(bool survey) async => [];
  @override
  Future<List<Map<String, dynamic>>> technicians() async => [];
}

Widget host(Widget child, {bool arabic = false}) => MaterialApp(
  locale: Locale(arabic ? 'ar' : 'en'), supportedLocales: const [Locale('ar'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: child),
);

void main() {
  for (final arabic in [false, true]) {
    testWidgets('Price add edit disable cancel and invalid input; Arabic=$arabic', (tester) async {
      final repository = MemoryRequests();
      await tester.pumpWidget(host(RequestAdmin(english: !arabic, mode: 0, repository: repository), arabic: arabic));
      await tester.pumpAndSettle();
      for (var attempt = 0; attempt < 3; attempt++) {
        await tester.tap(find.byType(ListTile).first);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), attempt == 0 ? '0' : '250');
        final save = find.widgetWithText(FilledButton, arabic ? 'حفظ' : 'Save');
        if (attempt == 0) {
          await tester.tap(save); await tester.pumpAndSettle();
          expect(find.byType(PriceEditor), findsOneWidget);
          await tester.enterText(find.byType(TextFormField), arabic ? '٢٥٠٫٥٠' : '250.50');
        }
        if (attempt == 1) await tester.tap(find.byType(SwitchListTile));
        await tester.tap(attempt == 2 ? find.text(arabic ? 'إلغاء' : 'Cancel') : save);
        // Exercise the reverse animation before route-owned controllers dispose.
        await tester.pump(); await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(repository.saves, 2);
      expect(repository.rows.single['is_active'], false);
    });
  }

  testWidgets('Price editor remains usable on a small phone with keyboard open', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(host(Builder(builder: (context) => TextButton(onPressed: () => showDialog<Map<String, dynamic>>(
      context: context, builder: (_) => const PriceEditor(english: true, property: 'apartment', problem: 'cockroaches')),
      child: const Text('Open')))));
    await tester.tap(find.text('Open')); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '200');
    await tester.tap(find.text('Save')); await tester.pumpAndSettle();
    expect(find.byType(PriceEditor), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Price save failure leaves a usable retryable dashboard', (tester) async {
    final repository = MemoryRequests()..failSave = true;
    await tester.pumpWidget(host(RequestAdmin(english: true, mode: 0, repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '300');
    await tester.tap(find.text('Save')); await tester.pumpAndSettle();
    expect(find.textContaining('Operation failed'), findsOneWidget);
    expect(tester.takeException(), isNull);
    repository.failSave = false;
    await tester.tap(find.byType(ListTile).first); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '300');
    await tester.tap(find.text('Save')); await tester.pumpAndSettle();
    expect(repository.saves, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Generic admin dialog owns its form through save and cancel transitions', (tester) async {
    Map<String, String>? result;
    await tester.pumpWidget(host(Builder(builder: (context) => TextButton(onPressed: () async {
      result = await showDialog<Map<String, String>>(context: context, builder: (_) => const AdminFieldsEditor(
        english: true, title: 'Branch', fields: ['name'], initial: {}, includeStatus: true));
    }, child: const Text('Open')))));
    await tester.tap(find.text('Open')); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Branch name');
    await tester.tap(find.text('Save')); await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(result?['name'], 'Branch name');
    await tester.tap(find.text('Open')); await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle();
    expect(result, isNull); expect(tester.takeException(), isNull);
  });
}
