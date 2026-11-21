# المرحلة الأولى — تصميم فقط، دون تحويل الاتصال

## حدود هذه المرحلة

أُضيفت ملفات جديدة فقط. لم يُحذف Firebase، ولم تتغير شاشة أو حزمة تشغيل أو إعداد بناء. `brand_config.dart` غير مستورد في الشاشات بعد. SQL مقترح للتطبيق اليدوي؛ لم يُنفّذ على أي مشروع Supabase، ولم تُستخدم أدوات اتصال Supabase لقراءة بياناتك أو تعديلها.

## 1. جرد Firebase الحالي

### Flutter

| الملف | الارتباط الحالي | التعامل معه الآن |
|---|---|---|
| `pubspec.yaml` | `firebase_core ^3.12.1`، `firebase_auth ^5.5.1`، `cloud_firestore ^5.6.5` | بدون تغيير |
| `lib/backend.dart` | تهيئة FirebaseOptions، معرّفات Android/iOS من dart-define، مشروع `ikill-4e337`، Firestore وإرسال `contact_submissions` | بدون تغيير |
| `lib/main.dart` | استدعاء Backend.initialize، قراءة `site_settings/global` و`branches` بـ snapshots | بدون تغيير |
| `lib/admin.dart` | Auth stream ودخول email/password وخروج وإعادة تحقق وتغيير كلمة المرور؛ CRUD للطلبات والفروع والإعدادات وقراءة الزيارات | بدون تغيير |
| `lib/request_form.dart` | يعتمد على Backend.ready وBackend.submit دون استيراد Firebase مباشرة؛ timestamp يضيفه backend | بدون تغيير |
| `tool/configure_firebase.py` | يحوّل Google client config إلى `firebase_build.json` | بدون تغيير |
| `firebase_build.json` | إعداد محلي متجاهَل في Git عند وجوده؛ لا تعرض محتواه | بدون تغيير |
| `test/app_test.dart` | اختبار تحميل المحتوى والشاشات دون Backend حي؛ يحتاج اختبارات انتقال لاحقًا | بدون تغيير |
| `.gitignore` | يستثني إعدادات Firebase المحلية وGoogle client files | بدون تغيير |
| `README.md`، `VERIFICATION.md` | تعليمات وتقرير تسليم Firebase التاريخي | بدون تغيير الآن |
| `source-manifest.json` | بصمات النسخة الأصلية، قد يتضمن أسماء ملفات Firebase وليس اتصالًا تنفيذيًا | بدون تغيير |

`Storage`: يوجد `storageBucket` في `backend.dart` فقط؛ **لا توجد حزمة firebase_storage ولا استدعاءات رفع/تحميل Storage في كود Flutter المفحوص**. `Firebase Analytics`: لا توجد حزمة firebase_analytics. إدخال measurementId في إعدادات الويب ليس دليلًا على تشغيل Analytics SDK في التطبيق.

### Android / iOS / البناء

- `.github/workflows/android-apk.yml`: يقرأ `GOOGLE_SERVICES_JSON` من Actions Secrets، ويشغّل أداة التحويل، ويبني بـ `--dart-define-from-file=firebase_build.json`. باقٍ كما هو.
- `android/app/build.gradle.kts` و`android/settings.gradle.kts`: ملفات البناء مفحوصة؛ لا يوجد Google Services plugin مضاف يدويًا. حزم Flutter توفر تكامل Firebase الأصلي.
- `ios/Podfile` و`ios/Runner/AppDelegate.swift` وملفات Xcode: تكامل Flutter/plugins، لا توجد تهيئة Firebase مستقلة يدويًا ظاهرة فيها. الحزم الأصلية تُحلّ أثناء البناء.
- `google-services.json` و`GoogleService-Info.plist`: أسماء مدعومة بأداة التحويل ومستثناة من Git؛ ملف المرفق السابق ليس مطلوبًا نسخه أو كشفه في هذه المرحلة. لا حاجة لمفاتيح جديدة أو أسرار Supabase الآن.

### موقع الويب في جذر المستودع — يجب ألا يُنسى عند الانتقال الكامل

| الملفات | الاستخدام |
|---|---|
| `firebase-config.js` | web config، firebase.initializeApp، window.auth وwindow.db، storageBucket كإعداد فقط |
| `firebase-loader.js` | تحميل app/firestore compat SDK **10.12.2** مؤجّلًا، ثم config وanalytics |
| `app.js` | listeners للإعدادات `site_settings/global` والفروع `branches` |
| `analytics.js` | تسجيل `page_views` في Firestore مباشرة؛ ليس Firebase Analytics SDK |
| `contact.html` | إنشاء `contact_submissions` مع serverTimestamp |
| `admin-login.html` | app/auth compat، SESSION persistence، Auth listener وemail/password sign-in |
| `admin.html` | app/auth/firestore compat؛ حماية الواجهة بالـAuth؛ طلبات/زيارات/فروع/إعدادات؛ إعادة تحقق وتغيير كلمة المرور |
| `index.html`, `about.html`, `services.html`, `sectors.html`, `locations.html` | تضمين Firebase loader؛ `contact.html` يتضمنه أيضًا |
| `firebase.json`, `.firebaserc` | Hosting وإعداد المشروع وربط Firestore rules/indexes؛ CSP يسمح بنقاط Firebase/Google الحالية |
| `firestore.rules`, `firestore.indexes.json` | أمان وفهارس Firestore الحالية |
| `README.md` | وثائق Firebase وتشغيل ونشر الموقع |
| `app_update.py`, `branches_update.py`, `content_update.py` | أدوات تعديل تاريخية تحتوي نصوص Firebase؛ ليست Backend حيًا، لكن إعادة تشغيلها قد تعيد النصوص القديمة |

المجموعات الحالية: `contact_submissions`, `branches`, `site_settings`, `page_views`. الجداول التشغيلية الجديدة **ليست تحويلًا آليًا 1:1** لهذه المجموعات. لم تُرحَّل الطلبات أو المستخدمون أو بيانات الموقع. حساب Firebase Auth لا يصبح حساب Supabase Auth تلقائيًا.

**ملاحظة أمنية قائمة:** `firestore.rules` الحالية تعتبر أي authenticated user قادرًا على إدارة مجموعات الإدارة. لم نغيرها؛ المخطط الجديد لا يكرر هذا النموذج، بل يتحقق من دور وtenant وعضوية نشطة من قاعدة البيانات.

## 2. خطة الملفات

### ملفات جديدة في المرحلة الحالية

- `lib/config/brand_config.dart`: إعداد العلامة التجارية فقط، دون ربط الشاشات.
- `supabase/phase1_schema.sql`: DDL والعلاقات والمشغلات والفهارس وRLS ومنح الصلاحيات داخل transaction.
- `supabase/PHASE1_PLAN.md`: هذا الجرد والخطة والقرارات.
- `supabase/BOOTSTRAP.md`: تعليمات يدوية لإنشاء الشركة وأول أدمن بعد تطبيق المخطط.
- `supabase/tests/package.json`, `supabase/tests/.gitignore`, `supabase/tests/phase1.test.cjs`: اختبارات PostgreSQL محلية مستقلة عن Flutter.

### ملفات قد تتأثر لاحقًا فقط، بعد تأكيدك

1. `pubspec.yaml`: إضافة supabase_flutter، دون حذف Firebase قبل اكتمال تجربة الانتقال.
2. طبقة Auth/repositories جديدة مستقلة بدل الاستدعاءات المباشرة، مع feature flag واختبار رجوع.
3. `lib/backend.dart`، `lib/admin.dart`، `lib/main.dart`، `lib/request_form.dart`: نقل تدريجي للقراءات والكتابات دون dual-write افتراضي؛ إدخال brand_config تدريجيًا.
4. Auth migration منفصلة، وخطة ترحيل Firestore وتحقيق الأعداد والروابط والنسخ الاحتياطي.
5. إعداد Storage خاص وصلاحيات ملفات وتوقيع روابط قصيرة العمر قبل تفعيل الصور والتوقيع.
6. ملفات البناء والأسرار ومعرّفات Android/iOS والشعار واسم العرض: مراحل لاحقة؛ brand_config وحده لا يغيّر package/bundle/native display name.
7. حذف Firebase وCSP/Hosting ذات الصلة **في المرحلة النهائية فقط** بعد الموافقة والتحقق.

لا نعدّل هذه الملفات في المرحلة الحالية، ولا نشغّل بناءً أو نشرًا أو نغيّر PR عن بُعد.

## 3. White-label

الافتراضي: iKILL، الشعاران المحليان، الأساسي `#15803D`، الثانوي `#052E16`، الطوارئ `01020019042` على مدار الساعة، `info@ikill.net`، العملة `EGP`.

يمكن استخدام `BrandConfig.current` لاحقًا، أو إنشاء نسخ `const BrandConfig(...)` بحقن الإعدادات. مثال override مستقبلي:

```sh
flutter run --dart-define=BRAND_NAME=Example \
  --dart-define=BRAND_EMERGENCY_PHONE=01234567890 \
  --dart-define=BRAND_EMAIL=hello@example.com \
  --dart-define=BRAND_PRIMARY_ARGB=0xFF1565C0 \
  --dart-define=BRAND_CURRENCY=EGP
```

هذا المثال لن يغيّر الشاشات الآن لأنها لم تُربط بالإعداد بعد. لا تضع service_role keys في إعداد العلامة أو داخل التطبيق. تغيير العلامة ليس اختيار عضوية tenant؛ RLS يعتمد على Auth وهوية المستخدم في profiles فقط.

## 4. المخطط والعلاقات

- `tenants`: جدول إضافي لازم لمرجعية الشركات. هو جذر العلاقات؛ بقية الجداول تحمل tenant_id غير قابل للنقل.
- `profiles`: حساب Auth واحد إلى profile واحد وtenant واحد في هذه المرحلة. role محصور في admin/technician/client، وportal_enabled افتراضيًا false. حساب العميل مرتبط بـclients من نفس الشركة. لا trigger يحوّل بيانات التسجيل أو user_metadata إلى دور إداري.
- `services_catalog → pricing_matrix`: سعر سكني ثابت لكل service + property_type + problem_code داخل الشركة، مع currency وunique constraint.
- `clients → client_sites`: عميل واحد له مواقع متعددة، مع قطاع وعنوان وإحداثيات مضبوطة المدى.
- `client_sites → surveys`: معاينة موقع وخدمة اختيارية وموظف معاين وassessment وعرض سعر snapshot. نصوص JSON بنود العرض/الفاتورة snapshots وليست جداول محاسبية مُطبّعة منفصلة.
- `clients → contracts`: عقد على عميل كامل أو site محدد، ومعاينة اختيارية، ومدى تاريخي وvisits_per_month وbilling_cycle ومبلغ كل دورة.
- `client_sites + contracts + profiles → visits`: زيارة لموقع، عقد وخدمة اختياريان، وفني نشط من نفس الشركة أو NULL لحين الإسناد.
- `visits → visit_reports`: تقرير واحد لكل زيارة، مرتبط بالفني المسند فعلًا، اختيارات ونتائج وإجراءات وصور وتوقيع وحالة draft/submitted.
- `clients + sites/contracts/visits → invoices`: روابط اختيارية ضمن نفس العميل والشركة، ومبالغ numeric وإجمالي وحالة سداد مولّدان حسابيًا. status للمستند منفصل عن payment_status. المتأخرات تستنتج من due_on والسداد، لا عمود generated يعتمد على مرور الوقت.

المفاتيح الأجنبية مركبة بـtenant_id، مع قيود إضافية لنفس العميل والموقع والعقد والفني. روابط ملكية المستندات ثابتة حتى للأدمن؛ تصحيح ملكية مستند قديم يحتاج مستندًا جديدًا بدل نقل السجل إلى عميل/شركة أخرى. يمكن إعادة إسناد زيارة قبل وجود تقرير؛ بعد وجود تقرير يمنع FK تغيير الفني حتى لا ينفصل سجل التقرير عن صاحبه. لا cascade يمسح تاريخًا ماليًا أو تقارير؛ تُستخدم الحالات inactive/cancelled/void بدل الحذف المتسلسل.

دورية العقد بيانات فقط؛ **لا scheduler يولّد زيارات أو فواتير آليًا في هذه المرحلة**. لا تُحسب أسعار حقيقية من بيانات وهمية أو seed أسعار تجريبية.

## 5. سياسة الصلاحيات المقصودة

| المجال | أدمن الشركة | الفني | العميل مع portal_enabled=true |
|---|---|---|---|
| بيانات الشركات | قراءة وتعديل شركته فقط؛ لا إنشاء شركات من API | لا | لا؛ العلامة محلية حاليًا |
| profiles | إدارة أعضاء شركته | قراءة ملفه فقط | قراءة ملفه فقط |
| العملاء | إدارة شركته | لا | سجله فقط |
| المواقع | إدارة شركته | مواقع بها زيارات مسندة له فقط، لتحديد مكان الخدمة | مواقعه فقط |
| الكتالوج والأسعار والمعاينات | إدارة شركته | لا في المرحلة الأولى | لا؛ المعاينات قد تحمل ملاحظات داخلية |
| العقود | إدارة شركته | لا | عقوده غير المسودة فقط |
| الزيارات | إدارة شركته | قراءة زياراته فقط، دون تعديل الإسناد/الحالة عبر API | زياراته فقط |
| التقارير | إدارة شركته | قراءة تقارير زياراته وإنشاء/تعديل مسودته ثم تقديمها؛ لا تعديل بعد التقديم ولا حذف | التقارير submitted لزياراته فقط |
| الفواتير | إدارة شركته | لا | فواتيره issued فقط، دون تعديل السداد |

الاستثناء التشغيلي الوحيد للفني خارج صفوف الزيارات والتقارير هو موقع الزيارة المسندة له. لا يرى قائمة عملاء الشركة أو فواتيرها أو أدوار الآخرين.

- العميل portal_enabled=false أو profile غير موجود أو is_active=false لا يرى بيانات البوابة. إلغاء التفعيل نافذ من قاعدة البيانات دون انتظار تحديث JWT.
- tenant غير نشط يمنع كل الوصول العادي بما فيه الأدمن؛ إعادة تفعيله تكون من SQL موثوق/خادم إداري.
- لا صلاحيات anonymous على الجداول؛ إرسال طلبات عامة يحتاج endpoint مصمم لاحقًا مع rate limiting، وليس فتح INSERT للجداول التشغيلية.
- clients/technicians لا يملكون INSERT/UPDATE profiles؛ لا يستطيع المستخدم منح نفسه admin أو تعديل tenant/portal_enabled.
- SECURITY DEFINER فقط لدوال داخل app_private، مع search_path فارغ وأسماء مؤهلة، لمنع recursion في profiles RLS. لا تضف app_private لقائمة exposed API schemas.
- service_role والمشغّل postgres موثوقان ويتجاوزان RLS لأعمال الخادم؛ **لا يمكن لأي RLS حماية بياناتك إذا وضعت service_role في تطبيق المستخدم**.

## 6. الصور والتوقيع

SQL يخزن `photo_paths[]` و`customer_signature_path` فقط، لا ملفات ولا روابط عامة. **لا ينشئ buckets ولا يغيّر storage.objects policies**. الحفظ/التحميل للملفات غير مفعّل في المرحلة الحالية. لاحقًا نحتاج bucket خاصًا ومسارًا مثل tenant_id/visit_id/file، وسياسات مستقلة للتحقق من العضوية وإسناد الزيارة، وروابط موقعة قصيرة العمر. RLS على visit_reports وحده لا يحمي ملفات منشورة مسبقًا في bucket عام.

## 7. تطبيق SQL بأمان والاختبار

1. استخدم مشروع Supabase تجريبيًا/جديدًا أو خذ backup وتأكد أن أسماء الجداول غير مستخدمة.
2. افتح SQL Editor والصق **كل** `phase1_schema.sql` وشغّله مرة واحدة. المعاملة تفشل بالكامل عند وجود تضارب أسماء؛ لا يوجد DROP ولا IF NOT EXISTS يخفي اختلاف schema.
3. بعد النجاح اتبع BOOTSTRAP.md لإنشاء أول tenant/admin يدويًا بهوية Supabase Auth حقيقية، وليس Firebase UID.
4. لا تغيّر اتصال التطبيق بعد ذلك؛ أرسل تأكيد نجاح التنفيذ أو رسالة الخطأ وانتظر المرحلة التالية.
5. لا تختبر RLS عبر SQL Editor كمستخدم postgres وتتوقع حجبًا: هذا دور موثوق يتجاوز السياسات. اختبر لاحقًا بـJWT مستخدمين تجريبيين منفصلين.

نُفّذ المخطط محليًا على PostgreSQL داخل **PGlite 0.5.17**، مع محاكاة auth.users وauth.uid وأدوار Supabase. نجحت **57** assertions تشمل العزل بين شركتين، العزل بين عملاء/فنيين داخل نفس الشركة، منع ترقية الدور، البوابة المعطلة، منع anonymous، وحماية التقرير المقدم والمفاتيح المركبة. لم يتصل الاختبار بأي خادم ولم يرسل بيانات إنتاج.

لإعادة الاختبار محليًا:

```sh
cd التطبيق/supabase/tests
npm install
npm test
```

هذه ليست نتيجة اختبار على Supabase المستهدف أو Storage أو JWT فعلي. لا يوجد Flutter SDK محلي في بيئة هذه المرحلة، لذلك لم يُعد تشغيل Flutter analyze/build لملف brand_config الجديد. الاختبارات المحلية لا تستبدل اختبار Supabase نفسه بعد التطبيق اليدوي.

**نقطة التوقف: راجع SQL وطبّقه بنفسك وأكد المتابعة. لا ترحيل أو ربط أو إزالة Firebase أو تعديل للشاشات قبل ذلك.**
