> تحديث المرحلة الثانية: الشركة الافتراضية iKILL موجودة بالفعل؛ الكود أدناه يربط بها هوية Supabase Auth فعلية فقط. لا تعِد تشغيل مخططات الإنشاء.

# تهيئة أول شركة وأول أدمن — بعد مراجعة وتنفيذ phase1_schema.sql فقط

لا ينفّذ التطبيق هذه الخطوات، ولا يوجد إنشاء أدمن تلقائي عند التسجيل. لا تستخدم Firebase UID في profiles؛ يجب استخدام مستخدم **Supabase Auth**.

1. افتح مشروع Supabase التجريبي الذي طبّقت عليه المخطط.
2. من Authentication → Users أنشئ/ادعُ مستخدم الإدارة بالطريقة الرسمية. لا تنشئ كلمة مرور ثابتة داخل SQL أو المستودع.
3. غيّر البريد أدناه إلى بريد هذا المستخدم، ثم شغّل الكود من SQL Editor بدور postgres الموثوق. لا ترسله من تطبيق Flutter.

```sql
BEGIN;
DO $$
DECLARE
  admin_email text := 'REPLACE_WITH_YOUR_SUPABASE_AUTH_EMAIL';
  admin_id uuid;
  company_id uuid;
BEGIN
  IF admin_email = 'REPLACE_WITH_YOUR_SUPABASE_AUTH_EMAIL' THEN
    RAISE EXCEPTION 'Replace admin_email with your actual Supabase Auth email first';
  END IF;

  SELECT id INTO STRICT admin_id
  FROM auth.users WHERE lower(email) = lower(admin_email);

  SELECT id INTO STRICT company_id FROM public.tenants WHERE slug='ikill';

  INSERT INTO public.profiles(id,tenant_id,role,full_name,portal_enabled)
  VALUES (admin_id,company_id,'admin','iKILL administrator',false);

  RAISE NOTICE 'Company selected: %', company_id;
END;
$$;
COMMIT;
```

- شغّل هذه التهيئة مرة واحدة فقط؛ إذا كان profile موجودًا ستفشل المعاملة بدل استبدال البيانات.
- لا مستخدم مطابق = فشل كامل دون شركة نصف منشأة.
- `portal_enabled` خاص بدخول العميل؛ الأدمن والفني يستخدمان role وis_active، لذلك يكون false لهما.
- تهيئة عميل لاحقًا: أنشئ clients أولًا، ثم profiles بالـAuth id والـtenant_id ونفس client_id، وrole=client. ابدأ portal_enabled=false ثم فعّله من عملية إدارية موثوقة عند السماح بالدخول.
- في المرحلة الأولى المستخدم الواحد له شركة واحدة. تعدد أعضاء البوابة لنفس العميل ممكن بملفات profiles مختلفة؛ دخول نفس حساب Auth لأكثر من شركة يحتاج membership design لاحقًا.
- لا تنشئ شركة افتراضية عامة لكل signup، ولا تأخذ role أوtenant_id من user_metadata.
- لا تضع service_role أو بيانات حساب SQL في Flutter أو brand_config أو GitHub repository files.

**توقف بعد تهيئة واختبار المشروع التجريبي؛ لا تغيّر تطبيق Firebase الحالي حتى تؤكد المرحلة التالية.**
