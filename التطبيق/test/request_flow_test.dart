import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ikill_native/instapay_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikill_native/content.dart';
import 'package:ikill_native/request_form.dart';
import 'package:ikill_native/request_repository.dart';
import 'package:ikill_native/request_models.dart';

class FakeRequests extends RequestRepository {
  Map<String, dynamic>? submitted;
  bool paymentEnabled = true;
  @override
  Future<InstapayDestination?> paymentDestination() async => !paymentEnabled ? null : InstapayDestination('qr.png', 'Test beneficiary', base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a7WQAAAAASUVORK5CYII='));
  @override
  bool get ready => true;
  @override
  Future<ResidentialQuote?> quote(String property, String problem) async =>
    const ResidentialQuote(id: 'price-id', amount: '250.00', currency: 'EGP');
  @override
  Future<Map<String, dynamic>> submit(String requestId, Map<String, dynamic> payload) async {
    submitted = payload;
    return {'status': payload['kind'] == 'contract' ? 'survey_pending' : 'pending_schedule'};
  }
}

void main() {
  testWidgets('Missing administrator QR blocks payment without blocking business requests', (tester) async {
    final content = (await tester.runAsync(SiteContent.load))!;
    final repository = FakeRequests()..paymentEnabled = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: RequestForm(english: true, content: content, onPrivacy: () {}, repository: repository),
    ))));
    final fields = find.byType(TextFormField);
    for (var i = 0; i < 4; i++) {
      await tester.enterText(fields.at(i), ['Customer', '01020019042', 'test@example.com', 'Assiut address'][i]);
    }
    final price = find.text('Get price and continue to payment');
    await tester.ensureVisible(price);
    await tester.tap(price);
    await tester.pumpAndSettle();
    expect(find.textContaining('InstaPay is unavailable'), findsOneWidget);
    expect(find.text('250.00 EGP'), findsNothing);
    expect(repository.submitted, isNull);
  });

  testWidgets('Residential price step requires confirmation and never marks payment paid', (tester) async {
    final content = (await tester.runAsync(SiteContent.load))!;
    final repository = FakeRequests();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: RequestForm(english: true, content: content, onPrivacy: () {}, repository: repository),
    ))));
    final fields = find.byType(TextFormField);
    for (var i = 0; i < 4; i++) {
      await tester.enterText(fields.at(i), ['Customer', '01020019042', 'test@example.com', 'Assiut address'][i]);
    }
    final price = find.text('Get price and continue to payment');
    await tester.ensureVisible(price);
    await tester.tap(price);
    await tester.pumpAndSettle();
    expect(find.text('250.00 EGP'), findsOneWidget);
    expect(find.textContaining('no online payment gateway'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'Transfer 123');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Review and send'));
    await tester.tap(find.text('Review and send'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    expect(repository.submitted?['kind'], 'residential');
    expect(repository.submitted?['payment_reference'], 'Transfer 123');
    expect(repository.submitted?.containsKey('payment_review'), isFalse);
    expect(repository.submitted?.containsKey('tenant_id'), isFalse);
  });
}
