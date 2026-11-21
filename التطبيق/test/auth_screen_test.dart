import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikill_native/auth_repository.dart';
import 'package:ikill_native/auth_screens.dart';

class FakeAuth implements AuthGateway {
  @override
  bool get ready=>true;
  int logins=0,resets=0,signups=0,googles=0;
  @override
  Future<void> login(String email,String password) async {logins++;}
  @override
  Future<bool> register(String name,String phone,String email,String password) async {signups++;return true;}
  @override
  Future<void> reset(String email) async {resets++;}
  @override
  Future<void> google() async {googles++;}
}
void main(){
  testWidgets('Sign-in validates input and calls only Supabase gateway', (tester)async{
    final gateway=FakeAuth();
    await tester.pumpWidget(MaterialApp(home:AuthScreen(english:true,gateway:gateway)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign in securely'));
    await tester.tap(find.text('Sign in securely'));await tester.pumpAndSettle();
    expect(gateway.logins,0);expect(find.text('Enter a valid email address.'),findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0),'person@example.com');
    await tester.enterText(find.byType(TextFormField).at(1),'Password123!');
    await tester.ensureVisible(find.text('Sign in securely'));await tester.tap(find.text('Sign in securely'));await tester.pumpAndSettle();
    expect(gateway.logins,1);expect(tester.takeException(),isNull);
  });
  testWidgets('Forgot password sends neutral response without revealing account existence',(tester)async{
    final gateway=FakeAuth();
    await tester.pumpWidget(MaterialApp(home:AuthScreen(english:true,gateway:gateway)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Forgot password?'));await tester.tap(find.text('Forgot password?'));await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField),'person@example.com');
    await tester.ensureVisible(find.text('Send reset link'));await tester.tap(find.text('Send reset link'));await tester.pumpAndSettle();
    expect(gateway.resets,1);expect(find.textContaining('If this email is registered'),findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
