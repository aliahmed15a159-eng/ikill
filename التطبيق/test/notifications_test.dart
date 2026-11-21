import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikill_native/auth_service.dart';
import 'package:ikill_native/notifications_screen.dart';

void main() {
  test('Only known notification reference kinds map to tables', () {
    expect(notificationTable('visit'), 'visits');
    expect(notificationTable('survey'), 'surveys');
    expect(notificationTable('invoice'), 'invoices');
    expect(notificationTable('report'), 'visit_reports');
    expect(() => notificationTable('profiles'), throwsFormatException);
    expect(() => notificationTable(''), throwsFormatException);
  });
  const client = ProfileAccess({'role':'client','tenant_id':'tenant'});
  testWidgets('Paid invoice never offers another proof submission', (tester) async {
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:PaymentPanel(
      kind:'invoice',row:const {'status':'issued','payment_status':'paid','payment_confirmation_status':'paid'},
      profile:client,onChanged:() {},
    ))));
    expect(find.byType(TextField),findsNothing);
    expect(find.textContaining('Upload transfer proof'),findsNothing);
    expect(tester.takeException(),isNull);
  });
  testWidgets('Pending invoice review does not permit duplicate submission', (tester) async {
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:PaymentPanel(
      kind:'invoice',row:const {'status':'issued','payment_status':'partial','payment_confirmation_status':'pending_confirmation'},
      profile:client,onChanged:() {},
    ))));
    expect(find.byType(TextField),findsNothing);
    expect(find.textContaining('Confirm receipt'),findsNothing);
    expect(tester.takeException(),isNull);
  });
}
