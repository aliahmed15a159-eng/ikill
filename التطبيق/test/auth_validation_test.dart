import 'package:flutter_test/flutter_test.dart';
import 'package:ikill_native/auth_validation.dart';
import 'package:ikill_native/auth_flow.dart';
import 'package:ikill_native/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main(){
  test('Email and password validation',(){
    expect(validAuthEmail(' person@example.com '),isTrue);
    for(final value in ['bad','a@','a b@example.com','a@localhost']){expect(validAuthEmail(value),isFalse);}
    expect(strongAuthPassword('Password123'),isTrue);
    expect(strongAuthPassword('12345678'),isFalse);
    expect(strongAuthPassword('password'),isFalse);
    expect(passwordStrength('Password123!long'),4);
  });
  test('WhatsApp normalization matches server and accepts Arabic digits',(){
    expect(normalizedWhatsapp('٠١٠٢٠٠١٩٠٤٢'),'+201020019042');
    expect(normalizedWhatsapp('0020 1020019042'),'+201020019042');
    expect(normalizedWhatsapp('+20 (102) 001-9042'),'+201020019042');
    expect(normalizedWhatsapp('123'),isNull);
    expect(normalizedWhatsapp('https://bad.invalid'),isNull);
  });
  test('Mobile callbacks have exact allowlist',(){
    expect(AuthFlow.accepts(Uri.parse(AuthFlow.callback)),isTrue);
    expect(AuthFlow.accepts(Uri.parse(AuthFlow.recoveryCallback)),isTrue);
    for(final value in ['https://auth/callback','net.ikill.app://evil/callback','net.ikill.app://auth/recovery/evil','net.ikill.app://auth:123/callback']){expect(AuthFlow.accepts(Uri.parse(value)),isFalse);}
  });
  test('Unknown errors cannot leak provider details',(){
    const error=AuthException('secret-token-private-server-message');
    expect(friendlyAuthError(error),isNot(contains('secret')));
    expect(friendlyAuthError(const AuthException('raw',code:'invalid_credentials')),contains('غير صحيحة'));
  });
  test('Customer needs phone once and is not a contracted client',(){
    const customer=ProfileAccess({'role':'customer','tenant_id':'tenant','is_active':true,'tenant_active':true,'portal_enabled':false,'profile_incomplete':true});
    expect(customer.denial,isNull);expect(customer.incomplete,isTrue);
    expect(ProfileAccess({...customer.data,'profile_incomplete':false}).incomplete,isFalse);
    expect(ProfileAccess({...customer.data,'role':'client'}).denial,isNotNull);
  });
}
