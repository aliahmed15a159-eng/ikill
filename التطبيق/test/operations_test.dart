import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikill_native/operations_dashboard.dart';
import 'package:ikill_native/operations_repository.dart';

class MemoryOperations extends OperationsRepository {
  void Function()? onChange;
  bool closed = false;
  int summaryCalls = 0, assigned = 0, bulkAssigned = 0;
  String? filterClient, filterSite, filterTech;
  String state = 'scheduled';
  @override
  Future<Map<String, dynamic>> summary() async {
    summaryCalls++;
    return {'today':'2028-02-01','timezone':'Africa/Cairo','scheduled':state=='scheduled'?1:0,'in_progress':state=='in_progress'?1:0,'completed':state=='completed'?1:0,'new_surveys':2,'pending_schedule':3,'active_contracts':4,'unpaid_invoices':5};
  }
  @override
  Future<Map<String, dynamic>> contextData() async => {'tenant_id':'tenant',
    'clients':[{'id':'customer','name':'Factory'}],
    'sites':[{'id':'site','name':'Production site','client_id':'customer','is_active':true}],
    'technicians':[{'id':'tech','name':'Technician One','is_active':true}]};
  @override
  Future<List<Map<String, dynamic>>> visits(DateTime first, DateTime last, {String? client,String? site,String? technician}) async {
    filterClient=client;filterSite=site;filterTech=technician;
    return [{'id':'visit','client_id':'customer','site_id':'site','client_name':'Factory','site_name':'Production site',
      'local_day':'2028-02-01','local_time':'10:00','status':state,'contract_id':'agreement','site_address':'Assiut'}];
  }
  @override
  Future<OperationsSubscription> watch(String tenant, void Function() changed,void Function(bool) connection) async {
    onChange=changed;connection(true);return OperationsSubscription(() async {closed=true;});
  }
  @override
  Future<void> assign(String id,String? technician) async {assigned++;}
  @override
  Future<int> assignSite(String id,String? technician) async {bulkAssigned++;return 4;}
}
void main() {
  test('Calendar grid starts Monday and covers month boundaries including leap day', () {
    expect(calendarStart(DateTime(2028,2)),DateTime(2028,1,31));
    expect(calendarStart(DateTime(2028,5)).weekday,DateTime.monday);
    expect(visitColors.keys,containsAll(['scheduled','in_progress','completed','cancelled']));
  });
  testWidgets('Operations uses realtime invalidations and closes subscription on exit', (tester) async {
    final repository=MemoryOperations();
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:OperationsDashboard(english:true,repository:repository))));
    await tester.pumpAndSettle();
    expect(find.text('Realtime connected'),findsOneWidget);
    final before=repository.summaryCalls;
    repository.state='in_progress';repository.onChange!();
    await tester.pump(const Duration(milliseconds:400));await tester.pumpAndSettle();
    expect(repository.summaryCalls,greaterThan(before));
    await tester.pumpWidget(const SizedBox());await tester.pumpAndSettle();
    expect(repository.closed,isTrue);
  });
  testWidgets('Calendar filters and individual/bulk technician assignment are connected', (tester) async {
    tester.view.physicalSize=const Size(1000,2400);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final repository=MemoryOperations();
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:OperationsDashboard(english:true,repository:repository))));
    await tester.pumpAndSettle();
    final dropdowns=find.byType(DropdownButtonFormField<String>);
    await tester.tap(dropdowns.at(0));await tester.pumpAndSettle();
    await tester.tap(find.text('Factory').last);await tester.pumpAndSettle();expect(repository.filterClient,'customer');
    await tester.tap(dropdowns.at(1));await tester.pumpAndSettle();
    await tester.tap(find.text('Production site').last);await tester.pumpAndSettle();expect(repository.filterSite,'site');
    await tester.tap(dropdowns.at(2));await tester.pumpAndSettle();
    await tester.tap(find.text('Technician One').last);await tester.pumpAndSettle();expect(repository.filterTech,'tech');
    await tester.tap(find.text('Set default and bulk-assign selected site'));await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);await tester.pumpAndSettle();
    await tester.tap(find.text('Technician One').last);await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm assignment'));await tester.pumpAndSettle();expect(repository.bulkAssigned,1);
    await tester.ensureVisible(find.byTooltip('Assign technician'));await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Assign technician'));await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm assignment'));await tester.pumpAndSettle();expect(repository.assigned,1);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());await tester.pumpAndSettle();
  });
  testWidgets('Operations dashboard fits a narrow phone', (tester) async {
    tester.view.physicalSize=const Size(320,800);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:OperationsDashboard(english:false,repository:MemoryOperations()))));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView),const Offset(0,-1200));await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());await tester.pumpAndSettle();
  });
}
