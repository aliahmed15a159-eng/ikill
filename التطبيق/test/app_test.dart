import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ikill_native/main.dart';
import 'package:ikill_native/content.dart';
import 'package:ikill_native/request_form.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Export contains all public pages, original services and both languages', () async {
    final content = await SiteContent.load();
    expect(content.services.length, 6);
    expect(content.pages.keys, containsAll(['index', 'services', 'sectors', 'locations', 'about', 'privacy-policy', 'terms']));
    expect(content.t('nav.home', false), 'الرئيسية');
    expect(content.t('nav.home', true), isNot('nav.home'));
  });

  testWidgets('Arabic native home renders offline and language can switch', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final content = (await tester.runAsync(SiteContent.load))!;
    await tester.pumpWidget(IkillApp(content: content, preferences: prefs));
    await tester.pumpAndSettle();
    expect(find.text('EN'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(find.text('عربي'), findsOneWidget);
    expect(prefs.getBool('english'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Form validates required fields without a backend', (tester) async {
    final content = (await tester.runAsync(SiteContent.load))!;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: RequestForm(english: true, content: content, onPrivacy: () {}),
    ))));
    final state = tester.state<FormState>(find.byType(Form));
    expect(state.validate(), isFalse);
    await tester.pump();
    expect(find.text('This field is required'), findsWidgets);
  });
}
