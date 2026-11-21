import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikill_native/client_admin.dart';
import 'package:ikill_native/client_repository.dart';
import 'package:ikill_native/lifecycle_forms.dart';

class MemoryClients extends ClientRepository {
  final customer = <String, dynamic>{'id':'client','display_name':'Factory','client_type':'contract','status':'survey_pending'};
  final sites = <Map<String, dynamic>>[];
  final surveys = <Map<String, dynamic>>[];
  final contracts = <Map<String, dynamic>>[];
  final plans = <Map<String, dynamic>>[];
  int activations = 0;
  @override
  Future<Map<String, dynamic>> detail(String id) async => {'client':customer,'sites':sites,'surveys':surveys,'contracts':contracts,'plans':plans};
  @override
  Future<void> saveSite(String clientId, String id, Map<String, String> fields) async {
    sites.add({'id':id,'name':fields['name'],'address':fields['address'],'sector':fields['sector'],'latitude':fields['latitude'],'longitude':fields['longitude'],'contact_phone':fields['phone'],'is_active':true});
  }
  @override
  Future<void> saveSurvey(String clientId, String siteId, String surveyId, Map<String, String> fields) async {
    surveys.add({'id':surveyId,'site_id':siteId,'status':'completed','assessment':{'findings':fields['findings'],'site_details':fields['details']},'proposed_total':fields['price'],'currency':'EGP'});
  }
  @override
  Future<void> saveContract(String id, String clientId, Map<String, dynamic> values) async {
    contracts.add({'id':id,'status':'draft','app_managed':true,'starts_on':values['start'],'ends_on':values['end'],'billing_amount':values['total'],'currency':'EGP','billing_cycle':values['cycle']});
    plans.addAll([for (final p in values['plans'] as List) {...Map<String, dynamic>.from(p as Map),'contract_id':id}]);
  }
  @override
  Future<int> activate(String id, String signer, String reference) async {
    activations++; customer['status']='active'; contracts.single['status']='active'; return 12;
  }
}

void main() {
  test('Lifecycle validators reject invalid locations, dates and money', () {
    expect(validateLifecycleValue('91','latitude'), isNotNull);
    expect(validateLifecycleValue('NaN','longitude'), isNotNull);
    expect(validateLifecycleValue('2028-02-31','date'), isNotNull);
    expect(validateLifecycleValue('2028-02-29','date'), isNull);
    expect(validateLifecycleValue('0','money'), isNotNull);
    expect(validateLifecycleValue('٢٥٠٫٥٠','money'), isNull);
  });
  testWidgets('Client site survey contract and activation are connected in native UI', (tester) async {
    final repository = MemoryClients();
    await tester.pumpWidget(MaterialApp(home: ClientDetail(english:true,clientId:'client',repository:repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add site')); await tester.pumpAndSettle();
    final fields=find.byType(TextFormField);
    for(var i=0;i<6;i++) {
      await tester.enterText(fields.at(i),['Site one','Assiut','27.1','31.2','factory','01020019042'][i]);
    }
    await tester.tap(find.text('Save')); await tester.pumpAndSettle();
    expect(repository.sites.length,1); expect(tester.takeException(),isNull);
    await tester.scrollUntilVisible(find.text('Record findings and price'),200,scrollable:find.byType(Scrollable).first); await tester.pumpAndSettle();
    await tester.tap(find.text('Record findings and price')); await tester.pumpAndSettle();
    for(var i=0;i<3;i++) {
      await tester.enterText(find.byType(TextFormField).at(i),['Findings','Two production rooms','1000'][i]);
    }
    await tester.tap(find.text('Save')); await tester.pumpAndSettle();
    expect(repository.surveys.single['status'],'completed');
    await tester.scrollUntilVisible(find.text('New draft for all active sites'),200,scrollable:find.byType(Scrollable).first); await tester.pumpAndSettle();
    await tester.tap(find.text('New draft for all active sites')); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(2),'12000');
    await tester.tap(find.text('Save draft')); await tester.pumpAndSettle();
    expect(repository.plans.single['visits_per_month'],1);
    final activate=find.widgetWithText(FilledButton,'Sign and activate contract');
    await tester.scrollUntilVisible(activate,200,scrollable:find.byType(Scrollable).first); await tester.pumpAndSettle(); await tester.ensureVisible(activate); await tester.pumpAndSettle(); await tester.tap(activate); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0),'Representative');
    await tester.enterText(find.byType(TextFormField).at(1),'Paper agreement 123');
    await tester.tap(find.text('Save')); await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton,'Sign and activate contract').last); await tester.pumpAndSettle();
    expect(repository.activations,1); expect(repository.customer['status'],'active');
    expect(tester.takeException(),isNull);
  });
}
