from pathlib import Path
p=Path('/home/user/uploads/app.js'); s=p.read_text()
needle='''/* =============================================
   LANGUAGE MANAGER
   ============================================= */'''
if needle not in s: raise SystemExit('language marker missing')
block=r'''/* =============================================
   STATIC CONTENT TRANSLATOR
   Handles page copy that is not stored in data-i18n attributes.
   ============================================= */
const STATIC_EN_TRANSLATIONS = Object.freeze({
  'حلول آمنة وصديقة للبيئة': 'Safe, eco-friendly solutions',
  'استجابة سريعة على مدار الساعة': 'Rapid response, around the clock',
  'مكافحة الآفات': 'Pest Control',
  'حلول شاملة لمكافحة جميع أنواع الآفات باستخدام أحدث التقنيات وأكثرها أماناً.': 'Comprehensive control for every type of pest, using the latest and safest techniques.',
  'اكتشف المزيد': 'Discover more',
  'مكافحة الجراثيم - VORTEX™': 'Germ Control – VORTEX™',
  'تعقيم متطور بتقنية VORTEX™ لضمان بيئة خالية من الجراثيم الضارة.': 'Advanced VORTEX™ disinfection for an environment free of harmful germs.',
  'سلامة الغذاء': 'Food Safety',
  'برامج متخصصة لضمان سلامة الغذاء وتلبية المعايير الصحية الدولية.': 'Specialized programs that protect food safety and meet international health standards.',
  'النظافة والتعطير': 'Hygiene & Fragrance',
  'حلول شاملة للنظافة والتعطير تمنح مساحتك أجواء نقية وعطرة طوال اليوم.': 'Complete hygiene and fragrance solutions for a fresh, inviting space all day.',
  'الآفات التي نتعامل معها': 'Pests We Handle',
  'نقضي على كل آفة': 'We Eliminate Every Pest',
  'الصراصير': 'Cockroaches', 'القوارض': 'Rodents', 'البعوض': 'Mosquitoes', 'الذباب': 'Flies',
  'النمل الأبيض': 'Termites', 'النمل': 'Ants', 'بق الفراش': 'Bed Bugs', 'الأفاعي': 'Snakes',
  'العقارب': 'Scorpions', 'الطيور': 'Birds', 'العفن': 'Mould', 'وأكثر...': 'And more…',
  'القطاعات': 'Sectors', 'القطاعات التي نخدمها': 'Sectors We Serve',
  'المؤسسات الغذائية': 'Food Establishments', 'الرعاية الصحية': 'Healthcare',
  'قطاع الضيافة': 'Hospitality', 'التعليم': 'Education', 'الصناعة': 'Industry', 'البيع بالتجزئة': 'Retail',
  'لماذا iKILL': 'Why iKILL', 'ما يميزنا عن الآخرين': 'What Makes Us Different',
  'حلول آمنة 100%': '100% Safe Solutions',
  'نستخدم مواد معتمدة ومرخصة تماماً وآمنة للبشر والحيوانات الأليفة.': 'We use fully approved, licensed materials that are safe for people and pets.',
  'فريق متخصص': 'Specialist Team',
  'خبراء معتمدون دولياً مع أكثر من 15 عاماً من الخبرة في الصحة العامة.': 'Internationally certified experts with more than 15 years of public-health experience.',
  'استجابة فورية 24/7': 'Immediate 24/7 Response',
  'خدمة طوارئ على مدار الساعة لضمان استجابة فورية لحالات الإصابة الحرجة.': 'Emergency support around the clock for a swift response to critical infestations.',
  'العنوان': 'Address', 'الفرع الرئيسي': 'Head Office', 'القاهرة والجيزة': 'Cairo & Giza',
  'آراء عملائنا': 'Client Testimonials', 'ماذا يقولون عنا': 'What Our Clients Say',
  '“أفضل شركة مكافحة حشرات تعاملت معها. فريق محترف واستجابة سريعة جداً.”': '“The best pest-control company I have worked with. A highly professional team and very fast response.”',
  'أحمد السيد': 'Ahmed El Sayed', 'مدير مطعم': 'Restaurant Manager',
  '“خدمة احترافية للغاية. استخدموا مواد آمنة تماماً مع وجود أطفالنا في البيت.”': '“An exceptionally professional service. They used completely safe materials while our children were at home.”',
  'سارة خالد': 'Sara Khaled', 'ربة منزل': 'Homeowner',
  '“تعاملنا معهم لحماية مستودعاتنا. النتائج مذهلة والفريق محترف جداً.”': '“We worked with them to protect our warehouses. The results were excellent and the team was very professional.”',
  'محمد الشيخ': 'Mohamed El Sheikh', 'مدير عمليات': 'Operations Manager',
  'تم التطوير بواسطة': 'Developed by', 'علي أحمد': 'Ali Ahmed',
  '© iKILL 2026 - جميع الحقوق محفوظة': '© iKILL 2026 — All rights reserved',

  'حلول شاملة للصحة العامة': 'Comprehensive Public Health Solutions',
  'نقدم خدمات متكاملة ومبتكرة في مكافحة الآفات، التعقيم، سلامة الغذاء، والنظافة.': 'We deliver integrated, innovative pest control, disinfection, food safety, and hygiene services.',
  'حلول احترافية للقضاء على جميع أنواع الآفات': 'Professional solutions for eliminating every type of pest',
  'مكافحة الجرذان': 'Rat Control',
  'نقوم بتحديد أماكن الجرذان واستخدام تقنيات متقدمة للقضاء عليها بطرق آمنة وفعالة مع ضمان عدم عودتها.': 'We identify rat activity and use advanced, safe, effective techniques to eliminate it and prevent its return.',
  'مكافحة الفئران': 'Mouse Control',
  'خدمات متكاملة للكشف عن الفئران وإزالتها باستخدام أحدث الطرق والمواد الآمنة.': 'Complete mouse detection and removal using the latest safe methods and materials.',
  'مكافحة الصراصير': 'Cockroach Control',
  'علاجات متخصصة للقضاء على الصراصير باستخدام مواد آمنة وفعالة طويلة الأمد.': 'Targeted cockroach treatments with safe, long-lasting and effective materials.',
  'مكافحة البعوض': 'Mosquito Control',
  'برامج متكاملة لمكافحة البعوض والبعوض الناقل للأمراض باستخدام تقنيات متقدمة.': 'Integrated mosquito-control programs using advanced techniques, including disease-vector management.',
  'مكافحة الذباب': 'Fly Control',
  'حلول فعالة لمكافحة الذباب في المنازل والمنشآت التجارية والصناعية.': 'Effective fly-control solutions for homes and commercial and industrial facilities.',
  'مكافحة البق': 'Bed Bug Control',
  'خدمات شاملة للقضاء على البق باستخدام تقنيات حديثة وآمنة.': 'Complete bed-bug elimination using modern, safe techniques.',
  'حلول متقدمة للتعقيم والتطهير وجودة الهواء': 'Advanced disinfection, sanitation, and air-quality solutions',
  'الضمان لجودة الهواء الداخلي': 'Indoor Air Quality Assurance',
  'خدمة Vortex™ تقوم بتنظيف وتعقيم مجاري الهواء في أجهزة التكييف والتهوية للتخلص من الجراثيم والفطريات، مما يضمن تدفق هواء نقي وصحي وخالٍ تماماً من مسببات الأمراض والروائح الكريهة.': 'Vortex™ cleans and disinfects air ducts in air-conditioning and ventilation systems, removing germs and fungi for fresh, healthy air free from pathogens and unpleasant odours.',
  'اطلب الخدمة الآن': 'Request the Service Now',
  'إزالة العفن والفطريات': 'Mould & Fungi Removal',
  'نقدم خدمة إزالة العفن المتكاملة عبر مرحلتين: المعالجة والتطهير المباشر للقضاء على الجراثيم الفطرية، يتبعها تطبيق درع حماية طويل المدى لمنع عودتها للنمو مجدداً.': 'Our integrated mould-removal service has two stages: direct treatment and disinfection to eliminate fungal organisms, followed by a long-term protective shield to prevent regrowth.',
  'مناسب للمكاتب والمنازل والمخازن': 'Suitable for offices, homes, and warehouses',
  'استشارات وتدريب احترافي لتطبيق معايير الجودة العالمية': 'Professional consulting and training for global quality standards',
  'تدريب السلامة الغذائية': 'Food Safety Training',
  'برامج تدريبية معتمدة عالمياً للعاملين في قطاع الأغذية والمطاعم والفنادق لتطبيق أنظمة الهاسب وحفظ سلامة الأطعمة.': 'Globally recognised training for food-sector, restaurant, and hotel teams to apply HACCP systems and protect food safety.',
  'سلامة الأغذية': 'Food Safety', 'الاستشارات الغذائية': 'Food Consulting',
  'نقوم بمرافقة المنشآت لضمان مطابقتها للمواصفات القياسية، فحص نقاط التحكم الحرجة وتقييم الموردين وسلاسل التوريد.': 'We support facilities in meeting standards, checking critical control points, and assessing suppliers and supply chains.',
  'تقييم المخاطر': 'Risk Assessment', 'التدقيق الداخلي': 'Internal Auditing', 'الامتثال القانوني': 'Legal Compliance',
  'روائح عطرة وتطهير مستمر لمساحات أعمالك': 'Premium fragrance and continuous sanitation for your workplace',
  'أنظمة التعطير الفاخرة': 'Premium Fragrance Systems',
  'أجهزة نشر روائح ذكية وتناغم عطري مخصص لمداخل الفنادق والشركات الكبرى لتقديم تجربة ترحيبية لا تُنسى.': 'Smart scent-diffusion devices and bespoke fragrance harmonies for hotel entrances and major businesses, creating an unforgettable welcome.',
  'تعقيم دورات المياه': 'Washroom Sanitation',
  'موزعات صابون ومعقمات أوتوماتيكية، سلات مهملات صحية، وتطهير دوري للمرافق لضمان أعلى مستويات الأمان الصحي.': 'Automatic soap and sanitiser dispensers, hygienic waste bins, and regular facility sanitation for the highest health-safety standards.',
  'حماية وتطهير الأسطح': 'Surface Protection & Disinfection',
  'تطبيق معقمات متطورة على الأسطح المشتركة تضمن قتل البكتيريا والفيروسات لفترات طويلة مع الحفاظ على سلامة المواد.': 'Advanced disinfectants on shared surfaces provide long-lasting protection against bacteria and viruses while preserving material safety.',

  'نشط': 'Active', 'الفرع الرئيسي - القاهرة والجيزة': 'Head Office – Cairo & Giza',
  'هاتف': 'Phone', 'البريد الإلكتروني': 'Email', 'ساعات العمل': 'Working Hours',
  '24 ساعة / 7 أيام': '24 Hours / 7 Days', 'المقر الرئيسي': 'Head Office',
  'الاسم الكامل': 'Full Name', 'رقم الهاتف': 'Phone Number', 'العنوان بالتفصيل': 'Detailed Address',
  'نوع الخدمة': 'Service Type', 'خدمة مخصصة': 'Custom Service', 'رسالتك': 'Your Message',
  'معلومات الاتصال': 'Contact Information', 'الهاتف': 'Phone', 'متوفر 24/7': 'Available 24/7',
  'جاري الإرسال...': 'Sending…', 'شارع الملك فيصل الجيزة': 'King Faisal St., Giza, Egypt',
  'سياسة الخصوصية': 'Privacy Policy', 'شروط الاستخدام': 'Terms of Use'
});

const STATIC_EN_PLACEHOLDERS = Object.freeze({
  'محمد أحمد': 'Mohamed Ahmed',
  'مثال: الجيزة - شارع فيصل': 'Example: Giza – Faisal Street',
  'أخبرنا عن احتياجاتك...': 'Tell us about your needs…'
});

const StaticContentTranslator = {
  originals: new WeakMap(),
  placeholderOriginals: new WeakMap(),

  normalise(text) { return text.replace(/\s+/g, ' ').trim(); },

  set(lang) {
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    const nodes = [];
    let node;
    while ((node = walker.nextNode())) nodes.push(node);

    nodes.forEach(textNode => {
      const parent = textNode.parentElement;
      if (!parent || parent.closest('script, style, [data-i18n]')) return;
      if (!this.originals.has(textNode)) this.originals.set(textNode, textNode.nodeValue);
      const original = this.originals.get(textNode);
      const key = this.normalise(original);
      const translated = lang === 'en' ? STATIC_EN_TRANSLATIONS[key] : null;
      if (!translated) { textNode.nodeValue = original; return; }
      const prefix = (original.match(/^\s*/) || [''])[0];
      const suffix = (original.match(/\s*$/) || [''])[0];
      textNode.nodeValue = `${prefix}${translated}${suffix}`;
    });

    document.querySelectorAll('[placeholder]').forEach(el => {
      if (el.closest('[data-i18n]') || el.hasAttribute('data-i18n-placeholder')) return;
      if (!this.placeholderOriginals.has(el)) this.placeholderOriginals.set(el, el.getAttribute('placeholder'));
      const original = this.placeholderOriginals.get(el);
      el.setAttribute('placeholder', lang === 'en' && STATIC_EN_PLACEHOLDERS[original] ? STATIC_EN_PLACEHOLDERS[original] : original);
    });

    const file = location.pathname.split('/').pop() || 'index.html';
    const titles = {
      ar: {
        'index.html': 'iKILL | مكافحة الآفات والتعقيم وسلامة الغذاء في مصر',
        'services.html': 'خدمات مكافحة الآفات والتعقيم | iKILL مصر',
        'sectors.html': 'حلول مكافحة الآفات للقطاعات | iKILL مصر',
        'about.html': 'من نحن | iKILL Pest Control Services مصر',
        'locations.html': 'فروع iKILL وعنوان الشركة | مكافحة الآفات في مصر',
        'contact.html': 'اتصل بـ iKILL | طلب خدمة مكافحة آفات'
      },
      en: {
        'index.html': 'iKILL | Pest Control, Disinfection & Food Safety in Egypt',
        'services.html': 'Pest Control & Disinfection Services | iKILL Egypt',
        'sectors.html': 'Pest Control Solutions by Sector | iKILL Egypt',
        'about.html': 'About Us | iKILL Pest Control Services Egypt',
        'locations.html': 'iKILL Locations & Address | Pest Control in Egypt',
        'contact.html': 'Contact iKILL | Request Pest Control Service'
      }
    };
    if (titles[lang][file]) document.title = titles[lang][file];
  }
};

'''
s=s.replace(needle,block+needle,1)
# Trigger static text conversion on the same call as regular language data attributes.
old='''    // Update placeholder-only translations
    document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
      const key = el.getAttribute('data-i18n-placeholder');
      const val = TRANSLATIONS[lang][key];
      if (val !== undefined) el.placeholder = val;
    });

    // Update lang buttons'''
new='''    // Update placeholder-only translations
    document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
      const key = el.getAttribute('data-i18n-placeholder');
      const val = TRANSLATIONS[lang][key];
      if (val !== undefined) el.placeholder = val;
    });

    // Translate the remaining static page copy and form placeholders.
    StaticContentTranslator.set(lang);

    // Update lang buttons'''
if old not in s:raise SystemExit('set insertion target missing')
s=s.replace(old,new,1)
p.write_text(s)
print('static language translations added')
