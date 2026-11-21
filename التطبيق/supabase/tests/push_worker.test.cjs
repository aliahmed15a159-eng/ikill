// Run real handler against mocked service RPC/provider. Never sends a real push.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),ts=require('typescript'),Module=require('node:module');
const source=fs.readFileSync(path.join(__dirname,'../functions/push-notification/index.ts'),'utf8').replace("import { createClient } from 'npm:@supabase/supabase-js@2.49.4';","const createClient=()=>globalThis.mockService;").replace("if (typeof Deno !== 'undefined') Deno.serve(handler);",'');
const code=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}});
const mod=new Module(__filename+'-virtual',module);mod._compile(code.outputText,__filename+'-virtual');
const {handler}=mod.exports;
const id='00000000-0000-0000-0000-000000000001',token='00000000-0000-0000-0000-000000000002';
let calls=[],claim={skip:true},claimError=false,sends=0,providerOk=true,hasKey=false;
global.Deno={env:{get:n=>n==='ONESIGNAL_REST_API_KEY'?(hasKey?'test-key':undefined):id}};
global.mockService={rpc:async(name,args)=>{calls.push({name,args});return {data:name==='claim_push_delivery'?claim:null,error:name==='claim_push_delivery'&&claimError?{message:'invalid'}:null};}};
global.fetch=async(url,options)=>{sends++;assert.equal(url,'https://api.onesignal.com/notifications?c=push');const body=JSON.parse(options.body);assert.equal(body.data.notification_id,id);assert.deepEqual(body.include_subscription_ids,[token]);assert.equal(body.headings.ar,'Test brand');assert.equal(body.contents.ar.includes('customer'),false);return Response.json(providerOk?{id:token}:{errors:['redacted']},{status:providerOk?200:400});};
const post=body=>handler(new Request('https://example.invalid',{method:'POST',body:typeof body==='string'?body:JSON.stringify(body)}));
(async()=>{
 assert.equal((await handler(new Request('https://example.invalid'))).status,405);
 assert.equal((await post({})).status,400);assert.equal(calls.length,0);
 assert.equal((await post('x'.repeat(2049))).status,413);
 claimError=true;assert.equal((await post({notification_id:id,token})).status,403);claimError=false;
 assert.deepEqual(await (await post({notification_id:id,token})).json(),{skipped:true});assert.equal(sends,0);
 claim={app_id:id,subscription_id:token,company_name:'Test brand',idempotency_key:token};
 assert.deepEqual(await (await post({notification_id:id,token})).json(),{configured:false});assert.equal(sends,0);assert.equal(calls.at(-1).args.result,'not_configured');
 hasKey=true;assert.deepEqual(await (await post({notification_id:id,token})).json(),{sent:true});assert.equal(sends,1);assert.equal(calls.at(-1).args.result,'sent');
 providerOk=false;assert.equal((await post({notification_id:id,token})).status,502);assert.equal(calls.at(-1).args.result,'failed');
 console.log('PASS: push handler validation, token claim, unconfigured, privacy, success and failure checks');
})().catch(e=>{console.error(e);process.exit(1)});
