import 'package:flutter_test/flutter_test.dart';
import 'package:ikill_native/push_service.dart';

void main() {
  test('FCM routes only canonical notification IDs; reference payload is not trusted', () {
    const id='00000000-0000-0000-0000-000000000001';
    expect(PushService.notificationId({'notification_id':id,'type':'visit_assigned','reference_id':'untrusted'}),id);
    expect(PushService.notificationId({'reference_id':id,'type':'invoice'}),isNull);
    expect(PushService.notificationId({'notification_id':List.filled(36,'-').join()}),isNull);
    expect(PushService.notificationId({'notification_id':123}),isNull);
    expect(PushService.notificationId({'notification_id':'https://example.invalid'}),isNull);
  });
  test('Push readiness does not imply provider delivery', () {
    const missing=PushState('Native configuration missing');
    expect(missing.configured,isFalse);
    expect(missing.registered,isFalse);
    const registered=PushState('Registered; sending disabled',configured:true,permission:true,registered:true);
    expect(registered.registered,isTrue);
    expect(registered.enabled,isFalse);
  });
}
