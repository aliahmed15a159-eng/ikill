import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'supabase_client.dart';

String whatsappPhone(String value) {
  var number=value.replaceAll(RegExp(r'[^0-9+]'),'');
  if(number.startsWith('00'))number=number.substring(2);
  if(RegExp(r'^01[0125][0-9]{8}$').hasMatch(number))number='2$number';
  number=number.replaceAll('+','');
  if(!RegExp(r'^[1-9][0-9]{7,14}$').hasMatch(number))throw const FormatException('International phone required');
  return number;
}
class DocumentsRepository {
  const DocumentsRepository();
  Future<List<Map<String,dynamic>>> rows(String table,String select,{String? client,String? filter,String? equals}) async {
    final account=await AuthService.profile();
    final result=<Map<String,dynamic>>[];
    for(var offset=0;;offset+=100){
      var query=supabaseClient.from(table).select(select).eq('tenant_id',account.tenantId);
      if(client!=null)query=query.eq(table=='visit_reports'?'visits.client_id':'client_id',client);
      if(filter!=null)query=query.eq(filter,equals!);
      final page=await query.order('id').range(offset,offset+99);
      result.addAll(page);if(page.length<100)return result;
    }
  }
  Future<Map<String,dynamic>> load({String? client,bool portal=false}) async {
    final account=await AuthService.profile();
    if(portal&&account.role!='client')throw const AccessDenied('Client account required');
    if(!portal&&account.role!='admin')throw const AccessDenied('Admin required');
    final reports=await rows('visit_reports','*,visits!inner(client_id,client_sites(name)),document_jobs(*),report_invoices(invoice_id)',client:client,filter:'status',equals:'submitted');
    final invoices=await rows('invoices','*,clients(display_name,phone,email)',client:client,filter:'status',equals:'issued');
    final sites=portal?await rows('client_sites','*'): <Map<String,dynamic>>[];
    final visits=<Map<String,dynamic>>[];
    if(portal){
      for(var offset=0;;offset+=100){
        final page=await supabaseClient.from('visits').select('*,client_sites(name)').eq('tenant_id',account.tenantId)
          .inFilter('status',['scheduled','confirmed','in_progress']).gte('scheduled_start',DateTime.now().toUtc().toIso8601String()).order('scheduled_start').order('id').range(offset,offset+99);
        visits.addAll(page);if(page.length<100)break;
      }
    }
    return {'reports':reports,'invoices':invoices,'sites':sites,'visits':visits,'tenant':account.tenantId};
  }
  Future<void> generate(String report) async {await AuthService.profile();await supabaseClient.functions.invoke('app-documents',body:{'report_id':report});}
  Future<void> paid(String invoice,String reference) async {
    await AuthService.requireAdmin();await supabaseClient.rpc('record_invoice_paid',params:{'target_invoice':invoice,'reference':reference});
  }
  Future<String> url(String bucket,String path,{bool share=false}) async {
    await AuthService.profile();return supabaseClient.storage.from(bucket).createSignedUrl(path,share?86400:3600);
  }
  Future<RealtimeChannel> watch(String tenant,void Function() changed) async {
    final channel=supabaseClient.channel('documents-${DateTime.now().microsecondsSinceEpoch}');
    for(final table in ['visits','visit_reports','invoices','document_jobs','client_sites','clients','profiles']){
      channel.onPostgresChanges(event:PostgresChangeEvent.all,schema:'public',table:table,
        filter:PostgresChangeFilter(type:PostgresChangeFilterType.eq,column:'tenant_id',value:tenant),callback:(_)=>changed());
    }
    channel.subscribe((status,error){if(status==RealtimeSubscribeStatus.subscribed)changed();});return channel;
  }
}
