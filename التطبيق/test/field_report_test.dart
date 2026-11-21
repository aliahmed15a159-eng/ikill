import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikill_native/field_report_store.dart';
import 'package:ikill_native/field_report_form.dart';

Map<String,dynamic> exampleDraft()=>{'submission':reportSubmissionKey(),'pest':'rodents','severity':'low','actions':['inspection'],'materials':'Bait 10 g','notes':'Checked','signer':'Site representative','photos':<String>[],'strokes':[[[0.1,0.2],[0.6,0.8]]]};
class MemoryFieldStore extends FieldReportStore {
  Map<String,dynamic> value=exampleDraft();
  MemoryFieldStore():super(Directory('/unused'));
  @override
  Future<Map<String,dynamic>?> load(String visit) async => value;
  @override
  Future<dynamic> readJson(String name) async => null;
  @override
  Future<void> save(String visit,Map<String,dynamic> draft) async {value=draft;}
}
void main(){
  test('Offline draft survives store recreation, isolates users and persists media',()async{
    final root=await Directory.systemTemp.createTemp('field-report-test-');
    addTearDown(()=>root.delete(recursive:true));
    final store=FieldReportStore(Directory('${root.path}/tenant/user-a'));
    final draft=exampleDraft();
    await store.save('visit-1',draft);
    final image=File('${root.path}/camera.jpg');await image.writeAsBytes([1,2,3]);
    final name=await store.keepPhoto('visit-1',image.path);await image.delete();
    draft['photos']=[name];await store.save('visit-1',draft);
    final reopened=FieldReportStore(store.root);
    expect((await reopened.load('visit-1'))!['submission'],draft['submission']);
    expect(await (await reopened.photo('visit-1',name)).readAsBytes(),[1,2,3]);
    expect(await FieldReportStore(Directory('${root.path}/tenant/user-b')).load('visit-1'),isNull);
    await expectLater(store.visitDirectory('../escape'),throwsArgumentError);
    expect(await File('${store.root.path}/visit-1/draft.json.tmp').exists(),isFalse);
    await reopened.remove('visit-1');expect(await reopened.load('visit-1'),isNull);
  });
  test('Report requires checklist, materials and an actual signature stroke',(){
    final draft=exampleDraft();expect(validFieldReport(draft),isTrue);
    draft['strokes']=[];expect(validFieldReport(draft),isFalse);
    draft['strokes']=[[[0.1,0.1]]];expect(validFieldReport(draft),isFalse);
    draft['strokes']=[[[0.1,0.1],[0.5,0.5]]];draft['actions']=[];expect(validFieldReport(draft),isFalse);
    draft['actions']=['unexpected'];expect(validFieldReport(draft),isFalse);
    expect(reportSubmissionKey(),matches(RegExp(r'^[a-f0-9]{32}$')));
  });
  testWidgets('Report restores persisted offline fields and signature on a narrow phone',(tester)async{
    final store=MemoryFieldStore();
    tester.view.physicalSize=const Size(320,800);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home:FieldReportForm(tenant:'tenant',user:'user',visit:'visit',english:true,store:store)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(TextField).first,300,scrollable:find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Bait 10 g'),findsOneWidget);
    await tester.enterText(find.byType(TextField).first,'No chemicals used');
    await tester.pumpAndSettle();
    expect(store.value['materials'],'No chemicals used');
    expect(store.value['strokes'],isNotEmpty);
    expect((await store.load('visit'))!['materials'],'No chemicals used');
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());await tester.pumpAndSettle();

  });
}
