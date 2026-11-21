# iKILL — Native Flutter / Supabase

تطبيق Android وiOS بواجهات Dart/Flutter أصلية، دون WebView. يستخدم **supabase_flutter 2.8.4** للمصادقة وPostgreSQL وStorage. لا توجد حزم أو تهيئة SDK خلفية قديمة في مسار التشغيل الحالي.

## التشغيل

Flutter 3.29.3 وDart المرفق به، JDK 17 وAndroid SDK؛ لبناء iOS يلزم macOS/Xcode/CocoaPods.

```sh
flutter pub get
# عيّن القيم في بيئة shell لديك، لا تضع مفاتيح إدارية هنا.
export SUPABASE_URL='https://YOUR_PROJECT.supabase.co'
export SUPABASE_ANON_KEY='YOUR_PUBLISHABLE_OR_ANON_KEY'
python3 tool/configure_supabase.py
flutter run --dart-define-from-file=supabase_build.json
```

`SUPABASE_ANON_KEY` يقبل publishable key أو JWT بدور anon فقط. لا تضع service_role أو sb_secret في التطبيق. ملف الإعداد المحلي مستثنى من Git. عدم ضبط الإعداد يعرض المحتوى المحلي ويوقف العمليات المتصلة برسالة، دون نجاح وهمي.

## الاتصال والمصادقة

- `lib/supabase_client.dart`: عميل مركزي `supabaseClient` من متغيرات البناء.
- `lib/auth_service.dart`: Auth وتحقق profile والدور والبوابة وحالة العضوية والشركة.
- `get_my_profile` يرجع بيانات صاحب الجلسة فقط، حتى لو البوابة معطلة، لتقديم سبب رفض واضح. لا يمنحه صلاحيات قراءة بيانات البوابة.
- العميل `portal_enabled=false` يُرفض دخوله وتُنهى الجلسة محليًا. الملفات غير المنشأة أو الشركات/الحسابات المعطلة تُرفض.
- شاشة الإدارة الحالية للأدمن فقط؛ لم تُنشأ شاشات عملاء أو فنيين جديدة.
- تغيير كلمة المرور يعيد التحقق بكلمة المرور الحالية ثم يستخدم Auth updateUser.

**يجب تهيئة حساب Supabase Auth وprofile إداري أولًا**؛ حسابات الخلفية السابقة لا تُنقل تلقائيًا. لم يتم اختراع بريد/كلمة مرور أو منح أدمن تلقائيًا. راجع `supabase/BOOTSTRAP.md`.

## ربط الوظائف الحالية

- نموذج التواصل → RPC محدود `submit_contact_request` → `clients` بحالة lead، مع حفظ الخدمة والرسالة والعنوان؛ لا anonymous INSERT/SELECT مباشر للعملاء.
- قائمة الطلبات في الإدارة → clients. الحذف خاضع للعلاقات وقد يُرفض للعميل الذي له مستندات مرتبطة؛ لا cascade يمسح التاريخ.
- فروع الشركة → company_branches. هذه ليست client_sites؛ مواقع العملاء لا تُعرض كفروع عامة.
- إعدادات وإحصائيات الموقع → tenants.branding؛ القراءة العامة projection محدود عبر RPC.
- إحصائيات زيارات الموقع الموجودة → page_events، دون إضافة تتبّع موبايل جديد.
- الجداول التشغيلية من المرحلة الأولى باقية دون اختراع سجلات عقود/زيارات/أسعار.
- تحديث Flutter عند فتح الشاشات وبعد الحفظ والتنقل، بدل تفعيل Realtime على القاعدة دون داعٍ. الموقع يحافظ على واجهاته بقراءة دورية كل 20 ثانية.

## Storage الخاص

`lib/storage_service.dart` يوفّر upload/remove/signedUrl باستخدام SDK الرسمي:

| Bucket | الأنواع | الحد الأقصى |
|---|---|---|
| visit-images | JPEG / PNG / WebP | 10 MB |
| visit-signatures | PNG | 2 MB |
| invoice-pdfs | PDF | 20 MB |

كلها private. المسار tenant_id/document_id/random-filename. لا public URLs؛ الروابط الموقعة مدتها 60 ثانية. الفني يكتب صور/توقيع زياراته فقط قبل تقديم التقرير، ولا يعدّل ملفات تقرير مقدّم. العميل يقرأ فقط الملفات المربوطة بتقاريره المقدّمة أو PDF لفاتورته الصادرة. RLS هو المرجع النهائي، وليس فحص التطبيق.

لم تكن بالواجهات الحالية أزرار رفع أو محرر تقارير؛ لذلك أُضيفت طبقة الخدمة والسياسات **من غير اختراع واجهات جديدة**. اختبارات الملفات المحلية لا تعني أن رفعًا فعليًا بحساب مستخدم قد جُرّب. الروابط الموقعة الموجودة تظل صالحة حتى انتهاء مدتها القصيرة بعد إلغاء الصلاحية.

## قاعدة البيانات

لتركيب جديد فقط: طبّق `supabase/phase1_schema.sql` ثم `supabase/phase2_integration.sql`. المشروع المتصل طُبّقت عليه المراحل بالفعل؛ **لا تعِد تنفيذ الإنشاء**. سجل التنفيذ والاختبارات في `supabase/PHASE2_STATUS.md`.

الدوال العامة للتحقق/التواصل ضيقة النطاق. quota التواصل خمسة طلبات لكل بريد/شركة/24 ساعة ليست حماية CAPTCHA أو IP rate limiting؛ يلزم ضبط حماية الحافة قبل فتح حمل إنتاجي كبير. page_events يحافظ على تتبع الويب السابق ولا يمنع إساءة إرسال الأحداث على مستوى IP؛ لا تعتبره أرقامًا محاسبية موثقة.

## التحقق والبناء

```sh
python3 tool/check_backend.py
flutter analyze --fatal-infos --fatal-warnings
flutter test
flutter build apk --debug --dart-define-from-file=supabase_build.json
```

GitHub Actions في `.github/workflows/android-apk.yml` يستخدم نفس الخطوات. متغيرا Actions `SUPABASE_URL` و`SUPABASE_ANON_KEY` يمكن تخصيصهما من Repository Variables؛ الافتراضي رابط المشروع المتصل ومفتاحه publishable العام، لا سر إداري.

APK الناتج تجريبي بتوقيع debug، لا يُنشر مباشرةً في المتجر. iOS يحتاج بناء وتوقيع على Mac، ولم يُختبر هنا.

## توقف المرحلة

لا ميزات جديدة ولا ترحيل تلقائي لبيانات أو كلمات مرور قديمة. اختبر النسخة على هاتف بحساب Supabase مُهيّأ وتحقق من الدخول والطلبات والإدارة قبل أي توسعة. نجاح analyze/test/build لا يثبت اختبار Auth/Storage فعلي على هاتف.
