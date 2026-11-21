import { createClient } from 'npm:@supabase/supabase-js@2.49.4';

const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const oauthUrl='https://oauth2.googleapis.com/token';
const scope='https://www.googleapis.com/auth/firebase.messaging';
const encoder=new TextEncoder();
type Account={type:string;project_id:string;client_email:string;private_key:string;token_uri?:string};
export function readAccount(raw:string|undefined):Account|null {
  try {
    const a=JSON.parse(raw??'');
    if(a.type!=='service_account'||!/^[a-z][a-z0-9-]{4,62}$/.test(a.project_id)||typeof a.client_email!=='string'||!a.client_email.endsWith('.iam.gserviceaccount.com')||typeof a.private_key!=='string'||!a.private_key.includes('-----BEGIN PRIVATE KEY-----')||(a.token_uri&&a.token_uri!==oauthUrl))return null;
    return a;
  }catch(_){return null;}
}
function base64url(bytes:Uint8Array):string {
  let binary='';for(const byte of bytes)binary+=String.fromCharCode(byte);
  return btoa(binary).replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_');
}
function encoded(value:unknown):string{return base64url(encoder.encode(JSON.stringify(value)));}
async function importKey(a:Account){
  const pem=a.private_key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g,'');
  return crypto.subtle.importKey('pkcs8',Uint8Array.from(atob(pem),c=>c.charCodeAt(0)),{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['sign']);
}
let cached:{identity:string;token:string;until:number}|null=null;
let refreshing:Promise<string>|null=null;
export async function accessToken(a:Account,force=false):Promise<string> {
  const identity=a.project_id+'|'+a.client_email+'|'+a.private_key;
  if(!force&&cached?.identity===identity&&cached.until>Date.now()+60000)return cached.token;
  if(refreshing&&!force)return refreshing;
  const task=(async()=>{
    const now=Math.floor(Date.now()/1000);
    const input=encoded({alg:'RS256',typ:'JWT'})+'.'+encoded({iss:a.client_email,scope,aud:oauthUrl,iat:now,exp:now+3600});
    const signature=await crypto.subtle.sign('RSASSA-PKCS1-v1_5',await importKey(a),encoder.encode(input));
    const assertion=input+'.'+base64url(new Uint8Array(signature));
    const response=await fetch(oauthUrl,{method:'POST',signal:AbortSignal.timeout(15000),headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion})});
    const result=await response.json().catch(()=>({}));
    if(!response.ok||typeof result.access_token!=='string'||!result.access_token)throw new Error('OAUTH_FAILED');
    cached={identity,token:result.access_token,until:Date.now()+Math.min(3600,Math.max(0,Number(result.expires_in)||0))*1000};
    return result.access_token;
  })();
  refreshing=task;
  try{return await task;}finally{if(refreshing===task)refreshing=null;}
}
export function fcmMessage(delivery:any,id:string){
  return {message:{token:delivery.fcm_token,
    notification:{title:delivery.company_name,body:'لديك إشعار جديد. افتح التطبيق للاطلاع عليه. / You have a new notification.'},
    data:{notification_id:id,type:delivery.type,reference_id:delivery.reference_id,reference_kind:delivery.reference_kind},
    android:{priority:'high',notification:{tag:id}},
    apns:{headers:{'apns-collapse-id':id,'apns-push-type':'alert','apns-priority':'10'},payload:{aps:{sound:'default'}}},
  }};
}
// Database webhook JWT verification is disabled deliberately. Only a valid
// per-delivery token can claim an existing outbox row; RPCs are service-only.
// net remains an unexposed managed schema. Never log tokens/keys/provider bodies.
export async function handler(request:Request){
  if(request.method!=='POST')return Response.json({error:'POST_REQUIRED'},{status:405});
  if(Number(request.headers.get('content-length')??0)>2048)return Response.json({error:'TOO_LARGE'},{status:413});
  let service:any,id='',token='',claimed=false;
  try {
    const text=await request.text();if(text.length>2048)return Response.json({error:'TOO_LARGE'},{status:413});
    const input=JSON.parse(text);
    if(input.action==='status'){
      const authorization=request.headers.get('Authorization')??'';
      if(!authorization.startsWith('Bearer '))return Response.json({error:'UNAUTHORIZED'},{status:401});
      const caller=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:authorization}},auth:{persistSession:false}});
      const user=await caller.auth.getUser();if(user.error||!user.data?.user)return Response.json({error:'UNAUTHORIZED'},{status:401});
      const settings=await caller.rpc('get_notification_settings');if(settings.error)return Response.json({error:'FORBIDDEN'},{status:403});
      const a=readAccount(Deno.env.get('FIREBASE_SERVICE_ACCOUNT'));
      let configured=false;
      if(a&&a.project_id===settings.data?.project_id){try{await importKey(a);configured=true;}catch(_){/* Invalid private key. */}}
      return Response.json({provider:'fcm',configured,enabled:settings.data?.push_enabled===true,webhook_enabled:settings.data?.webhook_enabled===true});
    }
    id=input.notification_id;token=input.token;
    if(typeof id!=='string'||typeof token!=='string'||!uuid.test(id)||!uuid.test(token))return Response.json({error:'INVALID_REQUEST'},{status:400});
    service=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
    const claim=await service.rpc('claim_push_delivery',{target:id,secret:token});
    if(claim.error)return Response.json({error:'INVALID_DELIVERY'},{status:403});
    const delivery=claim.data;if(delivery?.skip)return Response.json({skipped:true});
    claimed=true;
    const a=readAccount(Deno.env.get('FIREBASE_SERVICE_ACCOUNT'));
    if(!a||a.project_id!==delivery?.project_id){
      const finished=await service.rpc('finish_push_delivery',{target:id,secret:token,result:'not_configured'});
      if(finished.error)throw new Error('DELIVERY_RECORD_FAILED');
      return Response.json({configured:false});
    }
    let bearer=await accessToken(a);
    const send=()=>fetch(`https://fcm.googleapis.com/v1/projects/${a.project_id}/messages:send`,{method:'POST',signal:AbortSignal.timeout(15000),headers:{Authorization:`Bearer ${bearer}`,'Content-Type':'application/json'},body:JSON.stringify(fcmMessage(delivery,id))});
    let response=await send();
    if(response.status===401){bearer=await accessToken(a,true);response=await send();}
    const result=await response.json().catch(()=>({}));
    const sent=response.ok&&typeof result.name==='string'&&result.name.startsWith(`projects/${a.project_id}/messages/`);
    const unregistered=(result.error?.details??[]).some((e:any)=>e['@type']==='type.googleapis.com/google.firebase.fcm.v1.FcmError'&&e.errorCode==='UNREGISTERED');
    if(!sent&&unregistered){const cleared=await service.rpc('invalidate_fcm_token',{target:id,secret:token,device_token:delivery.fcm_token});if(cleared.error)throw new Error('TOKEN_CLEANUP_FAILED');}
    const finished=await service.rpc('finish_push_delivery',{target:id,secret:token,result:sent?'sent':unregistered?'no_device':'failed',provider_id:sent?result.name:null});
    if(finished.error)throw new Error('DELIVERY_RECORD_FAILED');
    return Response.json({sent},{status:sent?200:502});
  }catch(_){
    if(claimed)try{await service.rpc('finish_push_delivery',{target:id,secret:token,result:'failed'});}catch(_){/* Expired leases are retryable. */}
    return Response.json({error:'DELIVERY_FAILED'},{status:400});
  }
}
if (typeof Deno !== 'undefined') Deno.serve(handler);
