import { createClient } from 'npm:@supabase/supabase-js@2.49.4';

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
// JWT verification is disabled for the database webhook only. Every delivery is
// authenticated with an unexposed random token and claimed by service-only RPC.
// Never log request tokens, device IDs, provider keys or provider response bodies.
export async function handler(request: Request) {
  if (request.method !== 'POST') return Response.json({error:'POST_REQUIRED'},{status:405});
  if (Number(request.headers.get('content-length') ?? 0) > 2048) return Response.json({error:'TOO_LARGE'},{status:413});
  let service:any, id:string='', token:string='';
  let claimed=false;
  try {
    const text=await request.text();
    if(text.length>2048) return Response.json({error:'TOO_LARGE'},{status:413});
    const input=JSON.parse(text);
    id=input.notification_id;token=input.token;
    if(typeof id!=='string'||typeof token!=='string'||!uuid.test(id)||!uuid.test(token))return Response.json({error:'INVALID_REQUEST'},{status:400});
    service=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
    const claim=await service.rpc('claim_push_delivery',{target:id,secret:token});
    if(claim.error)return Response.json({error:'INVALID_DELIVERY'},{status:403});
    const delivery=claim.data;
    if(delivery?.skip)return Response.json({skipped:true});
    if(!delivery?.subscription_id||!delivery?.app_id)throw new Error('INVALID_CLAIM');
    claimed=true;
    const key=Deno.env.get('ONESIGNAL_REST_API_KEY');
    const configuredApp=Deno.env.get('ONESIGNAL_APP_ID');
    if(!key||!configuredApp||configuredApp!==delivery.app_id){
      await service.rpc('finish_push_delivery',{target:id,secret:token,result:'not_configured'});
      return Response.json({configured:false});
    }
    const response=await fetch('https://api.onesignal.com/notifications?c=push',{
      method:'POST',signal:AbortSignal.timeout(15000),
      headers:{'Authorization':`Key ${key}`,'Content-Type':'application/json'},
      body:JSON.stringify({
        app_id:delivery.app_id,target_channel:'push',include_subscription_ids:[delivery.subscription_id],
        headings:{en:delivery.company_name,ar:delivery.company_name},
        contents:{en:'You have a new notification. Open the app to view it.',ar:'لديك إشعار جديد. افتح التطبيق للاطلاع عليه.'},
        data:{notification_id:id},idempotency_key:delivery.idempotency_key,
      }),
    });
    const result=await response.json().catch(()=>({}));
    const sent=response.ok&&typeof result.id==='string'&&uuid.test(result.id);
    const finished=await service.rpc('finish_push_delivery',{target:id,secret:token,result:sent?'sent':'failed',provider_id:sent?result.id:null});
    if(finished.error)throw new Error('DELIVERY_RECORD_FAILED');
    return Response.json({sent},{status:sent?200:502});
  }catch(_){
    if(claimed)try{await service.rpc('finish_push_delivery',{target:id,secret:token,result:'failed'});}catch(_){/* Durable lease is retryable. */}
    return Response.json({error:'DELIVERY_FAILED'},{status:400});
  }
}
if (typeof Deno !== 'undefined') Deno.serve(handler);
