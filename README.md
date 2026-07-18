# iKILL Pest Control Services

موقع iKILL لخدمات مكافحة الآفات وحلول الصحة العامة في مصر.

**النطاق الرسمي:** [https://ikill.net](https://ikill.net)  
**بريد التواصل الرسمي:** [info@ikill.net](mailto:info@ikill.net)

---

## أهم المزايا

- واجهة عربية وإنجليزية مع تبديل اتجاه الصفحة تلقائياً RTL / LTR.
- تصميم أخضر وأبيض متجاوب مع وضع داكن.
- ملف `mobile.css` مستقل لضبط المقاسات والتخطيطات على الهواتف والشاشات الصغيرة.
- خلفية بيئية متحركة في الصفحة الرئيسية.
- شعار شفاف ونسخة مخصصة للوضع الداكن، بما فيها أيقونة المتصفح.
- قسم شركاء النجاح بحركة بطيئة ومتكررة، مع أزرار تنقّل والسحب بالماوس أو الهاتف.
- قائمة تنقل منبثقة تضم قوائم فرعية لكل صفحة رئيسية.
- نموذج تواصل متصل بـ Firebase Firestore.
- لوحة إدارة محمية بـ Firebase Authentication.
- بطاقة تفاصيل كاملة لكل طلب تواصل داخل لوحة الإدارة.
- صفحات سياسة الخصوصية وشروط الاستخدام.
- إعدادات SEO تشمل: Canonical URLs، Open Graph، Twitter Cards، Schema.org، `robots.txt`، و`sitemap.xml`.
- تحسينات أداء للصفحات العامة: CSS Utilities محلية بدلاً من Tailwind CDN، Firebase مؤجل، صورة Hero بصيغة WebP، وتحميل كسول للشعارات.

---

## تشغيل الموقع محلياً

لا تفتح ملفات الموقع مباشرة عبر `file://` عند اختبار Firebase. استخدم Live Server أو خادماً محلياً:

```bash
npx serve .
```

أو افتح مجلد المشروع بواسطة إضافة **Live Server** في VS Code.

بعدها افتح:

```text
http://localhost:3000
```

> رقم المنفذ قد يختلف حسب أداة التشغيل.

---

## النشر على Firebase Hosting

من داخل مجلد المشروع:

```bash
firebase login
firebase use ikill-4e337
firebase deploy
```

قبل النشر على النطاق الرسمي، أضف النطاقين التاليين في:

`Firebase Console → Authentication → Settings → Authorized domains`

```text
ikill.net
www.ikill.net
```

ثم اربط إعدادات DNS الخاصة بالنطاق مع Firebase Hosting من Firebase Console.

---

## إعداد محركات البحث

بعد نشر الموقع على `https://ikill.net`:

1. أضف الموقع إلى **Google Search Console**.
2. أرسل ملف خريطة الموقع التالي:

```text
https://ikill.net/sitemap.xml
```

3. تأكد أن الرابط التالي متاح للعامة:

```text
https://ikill.net/robots.txt
```

---

## لوحة الإدارة

- الوصول إلى صفحة الإدارة من خلال البحث في الموقع عن:

```text
info@ikill.net
```

- البحث يعرض رابطاً إلى `admin-login.html`.
- تسجيل الدخول الفعلي يتطلب حساباً صالحاً في **Firebase Authentication**؛ البحث لا يتجاوز الحماية.
- في قسم **طلبات التواصل**، اضغط على أي طلب أو زر العين لفتح بطاقة تفاصيل الطلب والتواصل مع العميل.

---

## هيكل الملفات الأساسي

```text
.
├── index.html                  # الصفحة الرئيسية
├── services.html               # الخدمات
├── sectors.html                # القطاعات
├── about.html                  # من نحن
├── locations.html              # الفروع والعنوان
├── contact.html                # نموذج التواصل
├── privacy-policy.html         # سياسة الخصوصية
├── terms.html                  # شروط الاستخدام
├── admin-login.html            # تسجيل دخول الإدارة
├── admin.html                  # لوحة التحكم
├── styles.css                  # التصميم العام
├── mobile.css                  # طبقة مقاسات الهواتف والشاشات الصغيرة
├── app.js                      # اللغة، الوضع الداكن، البحث، والواجهة العامة
├── admin-theme.css             # تصميم لوحة الإدارة
├── admin-login-theme.css       # تصميم صفحة دخول الإدارة
├── firebase-config.js          # تهيئة Firebase
├── firebase.json               # إعدادات Firebase Hosting
├── firestore.rules             # قواعد حماية Firestore
├── robots.txt                  # تعليمات محركات البحث
├── sitemap.xml                 # خريطة الموقع
├── site.webmanifest            # إعدادات التطبيق/المتصفح
└── img/
    ├── ikill-logo.png          # الشعار الافتراضي
    ├── ikill-logo-dark.png     # شعار الوضع الداكن وأيقونة التبويب
    ├── eco-environment-hero.jpg
    └── partners-clean/         # شعارات شركاء النجاح بخلفيات شفافة
```

---

## ملاحظات مهمة

- لا تحذف مجلد `img/partners-clean` لأنه يحتوي على شعارات سابقة الأعمال المستخدمة في الصفحة الرئيسية وصفحة «من نحن».
- لا تحذف `firestore.rules` عند النشر باستخدام Firebase، لأنه مرتبط بملف `firebase.json`.
- في حال عدم تحديث أيقونة التبويب بعد تفعيل الوضع الداكن، نفّذ تحديثاً إجبارياً للصفحة (`Ctrl + F5`).
- البريد الرسمي المستخدم في الموقع وSEO وبيانات التواصل هو: `info@ikill.net`.

---

تم التطوير بواسطة [علي أحمد](https://ali-ahmed-portfollio.vercel.app/).
