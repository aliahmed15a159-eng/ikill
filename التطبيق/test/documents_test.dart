import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikill_native/documents_repository.dart';
import 'package:ikill_native/documents_screen.dart';
import 'package:ikill_native/portal_admin.dart';

void main(){
  test('WhatsApp phone normalization supports Egyptian mobiles and explicit international numbers',(){
    expect(whatsappPhone('010 2001 9042'),'201020019042');
    expect(whatsappPhone('+20 1020019042'),'201020019042');
    expect(whatsappPhone('00971501234567'),'971501234567');
    expect(()=>whatsappPhone('088123'),throwsFormatException);
    expect(()=>whatsappPhone(''),throwsFormatException);
  });
  test('PostgREST one-to-one/list job representations are handled',(){
    expect(documentJob({'document_jobs':{'status':'ready'}})!['status'],'ready');
    expect(documentJob({'document_jobs':[{'status':'pending'}]})!['status'],'pending');
    expect(documentJob({'document_jobs':[]}),isNull);
    expect(documentJob({}),isNull);
  });
  testWidgets('Collection requires explicit reference and confirmation',(tester)async{
    String? result;
    await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>Scaffold(body:TextButton(onPressed:()async{result=await showDialog<String>(context:context,builder:(_)=>const CollectionDialog(english:true,total:'1000 EGP'));},child:const Text('open'))))));
    await tester.tap(find.text('open'));await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,isNull);
    await tester.enterText(find.byType(TextField),'Receipt 123');await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm collected'));await tester.pumpAndSettle();
    expect(result,'Receipt 123');
  });
  testWidgets('Client account dialog validates credentials without saving them',(tester)async{
    Map<String,String>? result;
    await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>Scaffold(body:TextButton(onPressed:()async{result=await showDialog<Map<String,String>>(context:context,builder:(_)=>const CreateClientAccountDialog(english:true,email:'client@example.invalid'));},child:const Text('open'))))));
    await tester.tap(find.text('open'));await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));await tester.pumpAndSettle();expect(result,isNull);expect(find.text('12+'),findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last,'TestOnly-Strong-123');await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));await tester.pumpAndSettle();expect(result?['email'],'client@example.invalid');expect(result?['password'],'TestOnly-Strong-123');
    expect(find.byType(CreateClientAccountDialog),findsNothing);
  });
}
