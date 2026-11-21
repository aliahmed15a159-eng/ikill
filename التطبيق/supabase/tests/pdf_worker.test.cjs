// Runs the deployed worker's renderer with real bundled OFL fonts. No live DB.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),ts=require('typescript');
const Module=require('node:module');
const {PDFDocument}=require('pdf-lib');
const root=path.join(__dirname,'../functions/app-documents');
let source=fs.readFileSync(path.join(root,'index.ts'),'utf8');
for(const [from,to] of [['npm:@supabase/supabase-js@2.49.4','@supabase/supabase-js'],['npm:pdf-lib@1.17.1','pdf-lib'],['npm:@pdf-lib/fontkit@1.1.1','@pdf-lib/fontkit'],['npm:bidi-js@1.0.3','bidi-js']])source=source.split(from).join(to);
const result=ts.transpileModule(source,{reportDiagnostics:true,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,esModuleInterop:true}});
assert.equal((result.diagnostics??[]).filter(d=>d.category===ts.DiagnosticCategory.Error).length,0);
const moduleFile=path.join(__dirname,'virtual-worker.cjs'),worker=new Module(moduleFile,module);
worker.filename=moduleFile;worker.paths=module.paths;worker._compile(result.outputText,moduleFile);
const {renderPdf,handler}=worker.exports;
const logo=Buffer.from(source.match(/const seedLogo='([^']+)'/)[1],'base64');
const arabic=fs.readFileSync(path.join(__dirname,'fixtures/NotoSansArabic-Regular.ttf'));
const latin=fs.readFileSync(path.join(__dirname,'fixtures/NotoSans-Regular.ttf'));
(async()=>{
 const data={brand:{company_name:'شركة الاختبار White Label',address:'أسيوط، مصر',phone:'01020019042',email:'test@example.invalid',tax_number:'123',primary_hex:'15803D'},client:{display_name:'عميل الاختبار'},site:{name:'فرع الإنتاج',address:'المنطقة الصناعية'},report:{id:'report-test',selections:{pest:'rodents',severity:'low',actions:['inspection'],materials:'مادة 10 جرام'},findings:'ملاحظات عربية طويلة للتأكد من تعدد الصفحات. '.repeat(250),customer_signer_name:'مسؤول الموقع',signed_at:'2026-11-21'},visit:{started_at:'2026-11-21',completed_at:'2026-11-21'},invoice:{invoice_number:'INV-TEST',issued_on:'2026-11-21',due_on:'2026-12-05',subtotal:1000,tax_amount:0,discount_amount:0,total:1000,amount_paid:0,payment_status:'unpaid',currency:'EGP',line_items:[{description:'Service',amount:1000}]}};
 const report=await renderPdf('report',data,arabic,logo,latin,[{bytes:logo,signature:true},{bytes:logo,signature:false}]);
 assert.equal(Buffer.from(report).subarray(0,4).toString(),'%PDF');assert.ok((await PDFDocument.load(report)).getPageCount()>1);
 const unpaid=await renderPdf('invoice',data,arabic,logo,latin);assert.equal((await PDFDocument.load(unpaid)).getPageCount(),1);
 data.invoice.amount_paid=1000;data.invoice.payment_status='paid';data.brand.company_name='علامة تجارية جديدة';data.brand.primary_hex='123456';
 const paid=await renderPdf('invoice',data,arabic,logo,latin);assert.ok(paid.length>1000);assert.notDeepEqual(Buffer.from(unpaid),Buffer.from(paid));
 assert.equal((await handler(new Request('https://example.invalid',{method:'GET'}))).status,405);
 assert.equal((await handler(new Request('https://example.invalid',{method:'POST',body:'{}'}))).status,400);
 console.log('PDF worker: 8 renderer/syntax/auth assertions passed; Arabic/Latin, pagination, images, signature, paid state and brand variations.');
})().catch(e=>{console.error(e);process.exit(1)});
