import { createClient } from 'npm:@supabase/supabase-js@2.49.4';
import { PDFDocument, rgb } from 'npm:pdf-lib@1.17.1';
import fontkit from 'npm:@pdf-lib/fontkit@1.1.1';
import bidiFactory from 'npm:bidi-js@1.0.3';

// Bootstrap only for the original tenant's seeded logo. Subsequent rendering
// always downloads brand_config.logo_path. White-label logos are admin uploads.
const seedLogo='iVBORw0KGgoAAAANSUhEUgAAAFkAAAAoBAMAAABnW0v4AAAAMFBMVEUDAwNJqhgeHh4rKyslJSVVVVVbrjH+/v6l0ZBxtVCcn5uGw2Z4tFlur06Qx3SFumf9K0J5AAAAEHRSTlMC9u5inhimAxtnBmMZlSokt4h3vQAAAuVJREFUeNrFlM9rE1sUxz8zk8kPbZM7BUXRxjTWhQqaxo0rra/dCWWePvd9/4CMKKgbDa5EBeNKRRBdCzIqVHAVEXkIFlNcKE9s01+819pmpmk0CUOnLiZNpzQpduXZ3HPv/dxzz/2eMwObMaXVxunQ/+sX5Vb0WNnYBC1I/XImfwVnpOLnZrGP6OvpYgnJXL8cIG3Nw3W4BOEMVHt7o6VAAQ7O3ITQIERLkf/ECp9MdhOStO3AHU3TPmlaJxeSyWRqq6ZpNhDUtB0rmSjgGgicR0QyoL6AMqPAdzbW5Dpw6srKbLkZLYOU9fwMqGEATMBtoqAcMZn13HHgdXZ1a7oJ7R63IgCcTUHb/UYVpLRsb5D3eeBVPbQK8pDYuwGdXQ3ND3CdLtdeXx2fvdq/2g/SyaHangVURx9qTof3+yYucsweZkBupXel4S15g9S7LTHstKCljD9OASjnvh4qtOrvh76TCICUqiZa0YurcdoT0wAOqE1pAzi68jGQyDkAtsmTpvQNoFZXeFSu33/IeVD896plZwGiSG0q6mxoC9z+W0D7RDgCVtItpIvfgo1IbWWA9glf3mFgMeMVJ7G2hlMAPPe/spIB7nmC5BA+uG2w3sd+TeaAGoAhG2u0WDQBwpk19A0dEMAtr/QNewzAAASUt1nlLm+zQG3fGVAdlLuxAqWuXW/q2YSnzwBcvo+0wT/yYn2sZfmdlmqoovgrH/qj2zAgAHLSaxIdwCYdxwDoAQzPVQgtxeTJnl3RkH0i/qVvtD9erXSP942KSjh9YPzaYnxy5tyWI+PpiTFAQY3ufBkrBd4dLsj/SFpwoURl1tKCzCe+Vqv3Oid7oqZmVe1gwetBdy7V8WFKt5HgvSJ35RNBdivwMSA6sGNjpIbpGJnSPVrK5y09bgqi/fR3OugFRy93wrFl29LJy+T7sPS498qldiSB5NqcWB6wcsJ6hnhq5QQLHV1Cyv+5dcRlRJhFc9Oy/gQkCuDockHvrAAAAABJRU5ErkJggg==';
const decode=(value:string)=>Uint8Array.from(atob(value.replace(/\s/g,'')),c=>c.charCodeAt(0));
const required=(result:any)=>{if(result.error)throw new Error(result.error.message);return result.data;};
const clean=(value:unknown)=>String(value??'').replace(/[\x00-\x08\x0b-\x1f]/g,'');
const labels:Record<string,string>={rodents:'قوارض',cockroaches:'صراصير',ants:'نمل',flies:'ذباب',mosquitoes:'بعوض',bedbugs:'بق',other:'أخرى',none:'لا يوجد',low:'منخفضة',medium:'متوسطة',high:'مرتفعة',inspection:'فحص',spraying:'رش',baiting:'طعوم',traps:'مصائد',sealing:'سد فتحات',sanitation:'نظافة',monitoring:'مراقبة',advice:'توعية'};

export async function renderPdf(kind:'report'|'invoice',data:any,fontBytes:Uint8Array,logoBytes:Uint8Array,latinBytes:Uint8Array,media:Array<{bytes:Uint8Array;signature:boolean}>=[]) {
  const pdf=await PDFDocument.create();pdf.registerFontkit(fontkit);
  const font=await pdf.embedFont(fontBytes,{subset:true});
  const latin=await pdf.embedFont(latinBytes,{subset:true});const bidi=bidiFactory();
  const runs=(text:string)=>{
    const rtl=/^[^A-Za-z\u0600-\u06ff]*[\u0600-\u06ff]/.test(text);
    const levels=bidi.getEmbeddingLevels(text,rtl?'rtl':'ltr').levels;const parts:any[]=[];
    let index=0;
    for(const char of text){const level=levels[index],arabic=/[\u0600-\u06ff]/.test(char);index+=char.length;const last=parts.at(-1);if(last&&last.level===level&&last.arabic===arabic)last.text+=char;else parts.push({text:char,level,arabic});}
    const max=Math.max(0,...parts.map(p=>p.level));const odd=parts.filter(p=>p.level%2).map(p=>p.level);const min=Math.min(...odd);
    for(let level=max;level>=min;level--){for(let a=0;a<parts.length;){if(parts[a].level<level){a++;continue;}let b=a;while(b<parts.length&&parts[b].level>=level)b++;const reversed=parts.slice(a,b).reverse();parts.splice(a,b-a,...reversed);a=b;}}
    return {rtl,parts};
  };
  const width=(text:string,size:number)=>runs(text).parts.reduce((n,p)=>n+(p.arabic?font:latin).widthOfTextAtSize(p.text,size),0);
  const draw=(text:string,x:number,y:number,size:number,color:any)=>{for(const p of runs(text).parts){const f=p.arabic?font:latin;page.drawText(p.text,{x,y,size,font:f,color});x+=f.widthOfTextAtSize(p.text,size);}};

  const logo=await pdf.embedPng(logoBytes).catch(()=>pdf.embedJpg(logoBytes));
  const hex=data.brand.primary_hex;const color=rgb(parseInt(hex.slice(0,2),16)/255,parseInt(hex.slice(2,4),16)/255,parseInt(hex.slice(4,6),16)/255);
  let page:any,y=0;let count=0;
  const next=()=>{page=pdf.addPage([595,842]);count++;y=728;page.drawRectangle({x:0,y:824,width:595,height:18,color});page.drawImage(logo,{x:42,y:755,width:95,height:43});draw(clean(data.brand.company_name),160,779,17,color);draw(`${kind==='invoice'?'INVOICE / فاتورة':'VISIT REPORT / تقرير زيارة'} — ${count}`,160,751,12,color);};
  const line=(text:unknown,size=11)=>{
    const words=clean(text).split(/\s+/);let current='';
    const flushLine=()=>{if(y<65)next();const measured=width(current,size);draw(current,runs(current).rtl?Math.max(42,553-measured):42,y,size,rgb(.1,.15,.12));y-=size+8;};
    for(const word of words){const candidate=current?`${current} ${word}`:word;if(width(candidate,size)>505&&current){flushLine();current='';}
      // Split long unbroken notes/identifiers so no field escapes the page.
      for(const char of (current?' ': '')+word){if(width(current+char,size)>505){flushLine();current='';}current+=char;}}
    if(current)flushLine();
  };
  next();
  line(data.brand.address);line(`${data.brand.phone} | ${data.brand.email}`);if(data.brand.tax_number)line(`الرقم الضريبي / Tax ID: ${data.brand.tax_number}`);
  line(`العميل / Client: ${data.client.display_name}`,13);
  if(kind==='report'){
    line(`الموقع / Site: ${data.site.name}`);line(data.site.address);line(`Report ID: ${data.report.id}`);line(`Start UTC: ${data.visit.started_at} | End UTC: ${data.visit.completed_at}`);
    const s=data.report.selections;line(`نوع الإصابة / Pest: ${labels[s.pest]??s.pest}`);line(`الحالة / Severity: ${labels[s.severity]??s.severity}`);
    line(`الإجراءات / Actions: ${(s.actions??[]).map((v:string)=>labels[v]??v).join(' / ')}`);
    line(`المواد / Materials: ${s.materials??data.report.actions_taken}`);line(`ملاحظات / Notes: ${data.report.findings??''}`);
    line(`مسؤول الموقع / Representative: ${data.report.customer_signer_name}`);line(`Signed/submitted UTC: ${data.report.signed_at}`);
    line('التوقيع المرسوم إقرار استلام، وليس توقيعاً رقمياً معتمداً. / Drawn acknowledgement, not a certified digital signature.',9);
    for(const entry of media){
      line(entry.signature?'توقيع مسؤول الموقع / Representative signature':'صورة الزيارة / Visit photo');
      const image=await pdf.embedPng(entry.bytes).catch(()=>pdf.embedJpg(entry.bytes));const scaled=image.scaleToFit(495,entry.signature?140:290);
      if(y-scaled.height<65)next();page.drawImage(image,{x:42,y:y-scaled.height,width:scaled.width,height:scaled.height});y-=scaled.height+18;
    }
    line(`الفاتورة المرتبطة / Linked invoice: ${data.invoice.invoice_number}`);
  }else{
    const i=data.invoice;line(`رقم الفاتورة / Invoice: ${i.invoice_number}`,12);line(`Issued: ${i.issued_on} | Due: ${i.due_on}`);
    if(i.billing_period)line(`دورة التعاقد / Billing period: ${i.billing_period} — ${i.period_end}`);
    for(const item of i.line_items??[])line(`${item.description}: ${Number(item.amount).toFixed(2)} ${i.currency}`);
    line(`Subtotal: ${Number(i.subtotal).toFixed(2)} | Tax: ${Number(i.tax_amount).toFixed(2)} | Discount: ${Number(i.discount_amount).toFixed(2)}`);
    line(`الإجمالي / Total: ${Number(i.total).toFixed(2)} ${i.currency}`,14);line(`المحصّل / Collected: ${Number(i.amount_paid).toFixed(2)} ${i.currency}`);
    line(`المتبقي / Balance: ${(Number(i.total)-Number(i.amount_paid)).toFixed(2)} ${i.currency}`);
    line(`حالة السداد / Payment: ${i.payment_status==='paid'?'مدفوعة / PAID':i.payment_status==='partial'?'مدفوعة جزئياً / PARTIAL':'غير مدفوعة / UNPAID'}`,14);
    line('فاتورة خدمة وليست إقراراً بالتكامل مع منظومة الفاتورة الضريبية الإلكترونية. / No tax-authority e-invoice integration is claimed.',9);
  }
  for(const p of pdf.getPages()){page=p;draw(`${data.brand.company_name} | ${kind} | ${pdf.getPages().indexOf(p)+1}/${pdf.getPageCount()}`,42,30,8,rgb(.35,.35,.35));}
  return pdf.save();
}

async function asset(service:any,bucket:string,path:string){return new Uint8Array(await required(await service.storage.from(bucket).download(path)).arrayBuffer());}
async function fontAsset(service:any,latin=false){
  const filename=latin?'NotoSans-Regular.ttf':'NotoSansArabic-Regular.ttf';
  const cached=await service.storage.from('document-assets').download(filename);
  if(!cached.error)return new Uint8Array(await cached.data.arrayBuffer());
  const response=await fetch(`https://api.github.com/repos/notofonts/noto-fonts/contents/hinted/ttf/${latin?'NotoSans':'NotoSansArabic'}/${filename}?ref=main`,{headers:{'Accept':'application/vnd.github+json'}});
  if(!response.ok)throw new Error('FONT_DOWNLOAD_FAILED');const value=await response.json();const bytes=decode(value.content);
  required(await service.storage.from('document-assets').upload(filename,bytes,{contentType:'font/ttf',upsert:true}));return bytes;
}
export async function handler(request:Request){
  if(request.method!=='POST')return Response.json({error:'POST required'},{status:405});
  let service:any,job:any,reportId='';
  try{
    const authorization=request.headers.get('Authorization')??'';if(!authorization.startsWith('Bearer '))throw new Error('UNAUTHORIZED');
    const url=Deno.env.get('SUPABASE_URL')!,anon=Deno.env.get('SUPABASE_ANON_KEY')!;
    const caller=createClient(url,anon,{global:{headers:{Authorization:authorization}},auth:{persistSession:false}});
    const user=required(await caller.auth.getUser()).user;if(!user)throw new Error('UNAUTHORIZED');
    const input=await request.json();service=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
    if(input.action==='create-client-account'){
      const profile=required(await caller.rpc('get_my_profile'));
      if(profile?.role!=='admin'||!profile.is_active||!profile.tenant_active)throw new Error('ADMIN_REQUIRED');
      const client=required(await caller.from('clients').select('id,display_name,portal_enabled').eq('id',input.client_id).eq('tenant_id',profile.tenant_id).single());
      if(typeof input.email!=='string'||input.email.length>254||!/^\S+@\S+\.\S+$/.test(input.email)||typeof input.password!=='string'||input.password.length<12||input.password.length>128)throw new Error('VALID_EMAIL_AND_12_CHARACTER_PASSWORD_REQUIRED');
      const existing=required(await service.from('profiles').select('id').eq('tenant_id',profile.tenant_id).eq('client_id',client.id).eq('role','client').limit(1));
      if(existing.length)throw new Error('CLIENT_ALREADY_HAS_ACCOUNT');
      const created=required(await service.auth.admin.createUser({email:input.email,password:input.password,email_confirm:true})).user;
      const result=await service.rpc('attach_portal_profile',{company:profile.tenant_id,customer:client.id,account:created.id});
      if(result.error){await service.auth.admin.deleteUser(created.id);throw new Error('PROFILE_CREATION_FAILED');}
      return Response.json({created:true});
    }
    if(input.action==='submit-report'){
      const id=required(await caller.rpc('submit_field_report',input.params));
      EdgeRuntime.waitUntil(handler(new Request(request.url,{method:'POST',headers:{'Authorization':authorization,'Content-Type':'application/json'},body:JSON.stringify({report_id:id})})));
      return Response.json({report_id:id,pdf_status:'pending'});
    }
    reportId=String(input.report_id??'');if(!/^[a-f0-9-]{36}$/i.test(reportId))throw new Error('REPORT_REQUIRED');
    job=required(await caller.rpc('claim_document_job',{target_report:reportId}));if(job.ready)return Response.json({ready:true});
    if(!job.brand||!job.brand.logo_path?.startsWith(`${job.tenant_id}/`)||job.brand.logo_path.includes('..')||job.brand.logo_path.includes('%'))throw new Error('BRAND_LOGO_REQUIRED');
    let logo:Uint8Array;
    try{logo=await asset(service,'brand-assets',job.brand.logo_path);}catch(error){
      const tenant=required(await service.from('tenants').select('slug').eq('id',job.tenant_id).single());
      if(tenant.slug!=='ikill'||job.brand.logo_path!==`${job.tenant_id}/logo.png`)throw error;
      logo=decode(seedLogo);required(await service.storage.from('brand-assets').upload(job.brand.logo_path,logo,{contentType:'image/png',upsert:false}));
    }
    const font=await fontAsset(service);const latin=await fontAsset(service,true);const media=[];
    const scoped=(path:string)=>{if(!path.startsWith(`${job.tenant_id}/${job.visit.id}/`)||path.includes('..')||path.includes('%'))throw new Error('INVALID_MEDIA_SCOPE');return path;};
    for(const path of job.report.photo_paths??[])media.push({bytes:await asset(service,'visit-images',scoped(path)),signature:false});
    if(job.report.customer_signature_path)media.push({bytes:await asset(service,'visit-signatures',scoped(job.report.customer_signature_path)),signature:true});
    const report=await renderPdf('report',job,font,logo,latin,media);const invoice=await renderPdf('invoice',job,font,logo,latin);
    const reportPath=`${job.tenant_id}/${job.visit.id}/${job.lease}.pdf`,invoicePath=`${job.tenant_id}/${job.invoice.id}/${job.lease}.pdf`;
    required(await service.storage.from('report-pdfs').upload(reportPath,report,{contentType:'application/pdf',upsert:false}));
    required(await service.storage.from('invoice-pdfs').upload(invoicePath,invoice,{contentType:'application/pdf',upsert:false}));
    required(await service.rpc('finish_document_job',{target_report:reportId,token:job.lease,report_file:reportPath,invoice_file:invoicePath,failure:null}));
    return Response.json({ready:true});
  }catch(error){
    if(job?.lease&&service){await service.rpc('finish_document_job',{target_report:reportId,token:job.lease,report_file:null,invoice_file:null,failure:'PDF_GENERATION_FAILED'});}
    // No request bodies, passwords, tokens, media or private signed URLs in logs.
    return Response.json({error:job?.lease?'PDF_GENERATION_FAILED':(error as Error).message},{status:400});
  }
}
// Edge runtime supplies these built-in credentials; none are shipped in Flutter.
if(typeof Deno!=='undefined')Deno.serve(handler);

declare const EdgeRuntime:{waitUntil(promise:Promise<unknown>):void};
