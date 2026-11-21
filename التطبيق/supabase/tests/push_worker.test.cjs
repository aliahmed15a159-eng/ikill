// Real HTTP-v1 handler + real ephemeral RSA signing; only OAuth/FCM/Supabase are mocked.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),ts=require('typescript'),Module=require('node:module');
const {webcrypto}=require('node:crypto');
global.crypto=webcrypto;
const source=fs.readFileSync(path.join(__dirname,'../functions/push-notification/index.ts'),'utf8').replace("import { createClient } from 'npm:@supabase/supabase-js@2.49.4';","const createClient=()=>globalThis.mockService;").replace("if (typeof Deno !== 'undefined') Deno.serve(handler);",'');
const code=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}});
const mod=new Module(__filename+'-virtual',module);mod._compile(code.outputText,__filename+'-virtual');
const {handler,readAccount}=mod.exports;
const id='00000000-0000-0000-0000-000000000001',token='00000000-0000-0000-0000-000000000002';
let calls=[],claim={skip:true},claimError=false,sends=0,oauthCalls=0,provider='ok',raw,authorized=true,publicKey,checks=0;
const eq=(a,b)=>{assert.deepEqual(a,b);checks++;};
global.Deno={env:{get:n=>n==='FIREBASE_SERVICE_ACCOUNT'?raw:'https://example.invalid'}};
global.mockService={auth:{getUser:async()=>({data:{user:authorized?{id}:null},error:null})},rpc:async(name,args)=>{calls.push({name,args});return {data:name==='claim_push_delivery'?claim:name==='get_notification_settings'?{project_id:'ikill-4e337',push_enabled:true,webhook_enabled:true}:null,error:name==='claim_push_delivery'&&claimError?{message:'invalid'}:null};}};
global.fetch=async(url,options)=>{
 if(url==='https://oauth2.googleapis.com/token'){
  oauthCalls++;
  const params=new URLSearchParams(options.body);eq(params.get('grant_type'),'urn:ietf:params:oauth:grant-type:jwt-bearer');
  const jwt=params.get('assertion'),[h,p,s]=jwt.split('.');
  eq(JSON.parse(Buffer.from(h,'base64url')).alg,'RS256');
  const payload=JSON.parse(Buffer.from(p,'base64url'));
  eq(payload.aud,url);eq(payload.scope,'https://www.googleapis.com/auth/firebase.messaging');eq(payload.exp-payload.iat,3600);eq(payload.iss,'sender@ikill-4e337.iam.gserviceaccount.com');
  eq(await crypto.subtle.verify('RSASSA-PKCS1-v1_5',publicKey,Buffer.from(s,'base64url'),Buffer.from(h+'.'+p)),true);
  return Response.json({access_token:'mock-access-'+oauthCalls,expires_in:3600,token_type:'Bearer'});
 }
 sends++;
 eq(url,'https://fcm.googleapis.com/v1/projects/ikill-4e337/messages:send');
 assert.match(options.headers.Authorization,/^Bearer mock-access-/);checks++;
 const body=JSON.parse(options.body);eq(body.message.token,'test-fcm-token');eq(body.message.android.priority,'HIGH');eq(body.message.data,{notification_id:id,type:'visit_assigned',reference_id:token,reference_kind:'visit'});eq(body.message.notification.title,'Test brand');
 eq(body.message.notification.body.includes('customer'),false);
 if(provider==='401'){provider='ok';return Response.json({error:{status:'UNAUTHENTICATED'}},{status:401});}
 if(provider==='unregistered')return Response.json({error:{details:[{'@type':'type.googleapis.com/google.firebase.fcm.v1.FcmError',errorCode:'UNREGISTERED'}]}},{status:404});
 if(provider==='failure')return Response.json({error:{status:'UNAVAILABLE'}},{status:503});
 return Response.json({name:'projects/ikill-4e337/messages/test-id'});
};
const post=(body,headers={})=>handler(new Request('https://example.invalid',{method:'POST',headers,body:typeof body==='string'?body:JSON.stringify(body)}));
(async()=>{
 eq((await handler(new Request('https://example.invalid'))).status,405);
 eq((await post({})).status,400);eq(calls.length,0);
 eq((await post('x'.repeat(2049))).status,413);
 claimError=true;eq((await post({notification_id:id,token})).status,403);claimError=false;
 eq(await (await post({notification_id:id,token})).json(),{skipped:true});eq(sends,0);
 claim={project_id:'ikill-4e337',fcm_token:'test-fcm-token',company_name:'Test brand',type:'visit_assigned',reference_id:token,reference_kind:'visit'};
 eq(await (await post({notification_id:id,token})).json(),{configured:false});eq(sends,0);eq(calls.at(-1).args.result,'not_configured');
 eq(readAccount('invalid'),null);eq(readAccount('{}'),null);
 const keys=await crypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},true,['sign','verify']);
 publicKey=keys.publicKey;
 const pem='-----BEGIN PRIVATE KEY-----\n'+Buffer.from(await crypto.subtle.exportKey('pkcs8',keys.privateKey)).toString('base64')+'\n-----END PRIVATE KEY-----';
 const account={type:'service_account',project_id:'ikill-4e337',client_email:'sender@ikill-4e337.iam.gserviceaccount.com',private_key:pem,token_uri:'https://oauth2.googleapis.com/token'};
 eq(readAccount(JSON.stringify({...account,token_uri:'https://malicious.invalid'})),null);
 raw=JSON.stringify(account);
 eq((await post({action:'status'})).status,401);
 eq((await (await post({action:'status'},{Authorization:'Bearer test'})).json()).configured,true);eq(oauthCalls,0);
 authorized=false;eq((await post({action:'status'},{Authorization:'Bearer test'})).status,401);authorized=true;
 eq(await (await post({notification_id:id,token})).json(),{sent:true});eq(sends,1);eq(oauthCalls,1);eq(calls.at(-1).args.result,'sent');
 eq(await (await post({notification_id:id,token})).json(),{sent:true});eq(oauthCalls,1);
 provider='401';eq((await post({notification_id:id,token})).status,200);eq(oauthCalls,2);
 provider='unregistered';eq((await post({notification_id:id,token})).status,502);eq(calls.at(-2).name,'invalidate_fcm_token');eq(calls.at(-1).args.result,'no_device');
 provider='failure';eq((await post({notification_id:id,token})).status,502);eq(calls.at(-1).args.result,'failed');
 claim.project_id='other-project';eq(await (await post({notification_id:id,token})).json(),{configured:false});
 console.log(`PASS: ${checks} FCM HTTP-v1/OAuth/RSA/privacy/status/failure assertions`);
})().catch(e=>{console.error(e);process.exit(1)});
