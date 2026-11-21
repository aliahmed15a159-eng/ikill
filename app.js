/**
 * iKILL Pest Control Services
 * Global App Script – Dark Mode + i18n + Animations
 * 2026
 */

/* =============================================
   COMPANY IDENTITY (single source of truth)
   ============================================= */
const COMPANY_EMAIL = 'info@ikill.net';
const COMPANY_DOMAIN = 'https://ikill.net';

function applyCompanyEmail() {
  document.querySelectorAll('[data-contact="email"]').forEach(el => {
    el.textContent = COMPANY_EMAIL;
  });
  document.querySelectorAll('a[href^="mailto:"]').forEach(link => {
    link.href = `mailto:${COMPANY_EMAIL}`;
    const textNode = [...link.querySelectorAll('span, div')].find(el => el.textContent.includes('@'));
    if (textNode) textNode.textContent = COMPANY_EMAIL;
  });
}

/* =============================================
   TRANSLATIONS (i18n)
   ============================================= */
const TRANSLATIONS = {
  ar: {
    // Navigation
    'nav.home':     'الرئيسية',
    'nav.services': 'خدماتنا',
    'nav.sectors':  'القطاعات',
    'nav.about':    'من نحن',
    'nav.branches': 'فروعنا',
    'nav.contact':  'اتصل بنا',
    'nav.cta':      'اطلب خدمة',

    // Top bar
    'topbar.emergency': 'طوارئ 24/7',
    'topbar.phone':     '01020019042',

    // Hero
    'hero.badge':    'الشركة الرائدة في الصحة العامة',
    'hero.title1':   'نحمي',
    'hero.title2':   'بيئتك',
    'hero.title3':   'باحترافية عالمية',
    'hero.subtitle': 'حلول متكاملة وآمنة لمكافحة الآفات. نخدمك في مصر بأعلى معايير الجودة.',
    'hero.cta1':     'احجز الآن',
    'hero.cta2':     'استكشف خدماتنا',
    'hero.clients':  'عميل راضٍ+',

    // Stats
    'stat1.value': '15', 'stat1.label': 'عام من الخبرة',
    'stat2.value': '1',  'stat2.label': 'فرع',
    'stat3.value': '240k','stat3.label': 'عميل موثوق',
    'stat4.value': '98', 'stat4.label': '% رضا العملاء',

    // Logos strip
    'logos.title': 'شركاء النجاح وسابقة أعمالنا',

    // Services section
    'services.badge':     'خدماتنا',
    'services.title':     'حلول مكافحة الآفات الاحترافية',
    'services.subtitle':  'نقدم حلولاً آمنة وفعالة لمكافحة الآفات وحماية منشآتك.',
    'services.all':       'استكشف مكافحة الآفات',

    // Locations section
    'locations.badge':    'فروعنا',
    'locations.title':    'نخدمك في كل مكان',
    'locations.subtitle': 'تواجدنا الواسع يضمن وصول خدماتنا إليك أينما كنت.',
    'locations.all':      'عرض جميع الفروع',
    'locations.loading':  'جاري تحميل الفروع...',
    'locations.empty':    'لا توجد فروع نشطة حالياً.',

    // CTA Banner
    'cta.badge':     'تواصل معنا اليوم',
    'cta.title':     'جاهزون لخدمتك على مدار الساعة',
    'cta.subtitle':  'فريقنا المتخصص يستجيب لطلباتك في أسرع وقت. اطلب الخدمة الآن واحصل على تقييم مجاني.',
    'cta.call':      'اتصل الآن',
    'cta.book':      'احجز خدمة',

    // Footer
    'footer.desc':    'الشركة الرائدة في الصحة العامة في مصر. نقدم حلولاً متكاملة ومعتمدة عالمياً.',
    'footer.company': 'الشركة',
    'footer.links':   'روابط سريعة',
    'footer.contact_title': 'تواصل معنا',
    'footer.address': 'شارع الملك فيصل، الجيزة، مصر',
    'footer.rights':  '© iKILL 2026 - جميع الحقوق محفوظة',
    'footer.privacy': 'سياسة الخصوصية',
    'footer.terms':   'شروط الاستخدام',

    // About page
    'about.since':    'منذ 2015',
    'about.title':    'iKILL - الشركة الرائدة في الصحة العامة',
    'about.subtitle': 'جزء من مجموعة Rentokil Initial العالمية. أكبر شركة صحة عامة في منطقة الشرق الأوسط وشمال أفريقيا.',
    'about.partners_title': 'شركاء النجاح وسابقة أعمالنا',
    'about.values_title':   'قيمنا الأساسية',
    'about.desc': 'تأسست iKILL في عام 2015 كجزء من مجموعة Rentokil Initial، وهي إحدى أكبر الشركات العالمية في مجال الخدمات الصحية والصحة العامة. تعمل الشركة في أكثر من 80 دولة وتخدم أكثر من 240 ألف عميل في المنطقة.',
    'about.vision_title': 'رؤيتنا',
    'about.vision_desc': 'أن نكون الشركة الأولى في تقديم حلول الصحة العامة المتكاملة في مصر والشرق الأوسط وأفريقيا.',
    'about.mission_title': 'مهمتنا',
    'about.mission_desc': 'تعزيز حياة الناس من خلال تقديم حلول فعالة وآمنة لمكافحة الآفات وتحسين جودة الحياة.',
    'about.stat1_lbl': 'سنة خبرة عالمية',
    'about.stat2_lbl': 'دولة نعمل بها',
    'about.stat3_lbl': 'عميل موثوق',
    'about.stat4_lbl': 'رضا العملاء',
    'about.value1_title': 'السلامة أولاً',
    'about.value1_desc': 'نضع سلامة عملائنا وموظفينا في مقدمة أولوياتنا.',
    'about.value2_title': 'الابتكار',
    'about.value2_desc': 'نستخدم أحدث التقنيات والحلول العلمية في خدماتنا.',
    'about.value3_title': 'الاستدامة',
    'about.value3_desc': 'نلتزم بتقديم حلول صديقة للبيئة ومستدامة.',
    'about.csr_badge': 'المسؤولية الاجتماعية والبيئية',
    'about.csr_title': 'الاستدامة في صلب عملنا',
    'about.csr_desc': 'نحن ملتزمون بتقليل الانبعاثات واستخدام الموارد الطبيعية لتطوير منتجات وعمليات صديقة للبيئة. كما نقدم برامج تدريبية ومشاركة مجتمعية لرفع مستوى الوعي بالصحة العامة.',
    'about.csr_tag1': 'برنامج "بيئة خضراء"',
    'about.csr_tag2': 'حملات التوعية',
    'about.csr_tag3': 'تقليل البلاستيك',
    'about.partners_subtitle': 'مجموعة من أكبر الشركات والمؤسسات التي وثقت في خدماتنا.',

    // Contact page
    'contact.title':     'تواصل معنا',
    'contact.subtitle':  'فريقنا جاهز للإجابة على استفساراتك وتقديم أفضل الحلول لك.',
    'contact.form.name':     'الاسم الكامل',
    'contact.form.phone':    'رقم الهاتف',
    'contact.form.email':    'البريد الإلكتروني',
    'contact.form.address':  'العنوان بالتفصيل',
    'contact.form.service':  'نوع الخدمة',
    'contact.form.message':  'رسالتك',
    'contact.form.submit':   'إرسال الطلب',
    'contact.social_follow': 'تابعنا على وسائل التواصل',

    // Sectors page
    'sectors.title':    'القطاعات التي نخدمها',
    'sectors.subtitle': 'نقدم حلولاً متخصصة لجميع القطاعات بأعلى معايير الجودة والسلامة.',
    'sectors.desc': 'حلول متكاملة ومخصصة لمختلف المجالات الصناعية والتجارية والخدمية.',
    'sectors.food_title': 'المؤسسات الغذائية',
    'sectors.food_desc': 'خدمات مكافحة آفات متكاملة للمطاعم والفنادق ومصانع الأغذية وسلاسل التوريد لدعم الامتثال لمتطلبات الصحة العامة.',
    'sectors.edu_title': 'المؤسسات التعليمية',
    'sectors.edu_desc': 'برامج مكافحة آفات للمدارس والجامعات والحضانات للحفاظ على بيئة تعليمية آمنة ومريحة للطلاب.',
    'sectors.health_title': 'الرعاية الصحية',
    'sectors.health_desc': 'حلول مكافحة آفات متخصصة للمستشفيات والعيادات والمراكز الطبية ومصانع الأدوية.',
    'sectors.ind_title': 'القطاع الصناعي',
    'sectors.ind_desc': 'خدمات حماية متطورة للمصانع والمنشآت الصناعية والمستودعات لحفظ المواد الخام والمنتجات النهائية من التلف.',
    'sectors.retail_title': 'البيع بالتجزئة',
    'sectors.retail_desc': 'برامج شاملة لمراكز التسوق ومحلات التجزئة والسوبرماركت لمنع دخول الآفات وتقديم مساحات تسوق نظيفة ومرحبة بزبائنكم.',
    'sectors.hosp_title': 'قطاع الضيافة',
    'sectors.hosp_desc': 'حماية علامتك التجارية وسمعتك في الفنادق والمنتجعات عبر برامج متكاملة تحافظ على راحة النزلاء وسلامتهم الدائمة.',

    // Services page
    'services.page_title':    'خدماتنا',
    'services.pest_title':    'مكافحة الآفات',

    // Search
    'search.placeholder': 'ابحث هنا...',
    'search.admin_hint':  'إدخال لوحة التحكم',

    // Branch info
    'branch.name':          'الفرع الرئيسي - الجيزة',
    'branch.country':       'مصر',
    'branch.address_label': 'العنوان',
    'branch.phone_label':   'هاتف',
    'branch.email_label':   'البريد الإلكتروني',
    'branch.hours_label':   'ساعات العمل',
    'branch.hours':         '24 ساعة / 7 أيام',
  },

  en: {
    // Navigation
    'nav.home':     'Home',
    'nav.services': 'Services',
    'nav.sectors':  'Sectors',
    'nav.about':    'About Us',
    'nav.branches': 'Branches',
    'nav.contact':  'Contact',
    'nav.cta':      'Request Service',

    // Top bar
    'topbar.emergency': 'Emergency 24/7',
    'topbar.phone':     '01020019042',

    // Hero
    'hero.badge':    'Leading Public Health Company',
    'hero.title1':   'We Protect',
    'hero.title2':   'Your Space',
    'hero.title3':   'With World-Class Expertise',
    'hero.subtitle': 'Complete, safe pest-control solutions. Serving Egypt to the highest quality standards.',
    'hero.cta1':     'Book Now',
    'hero.cta2':     'Explore Services',
    'hero.clients':  'Satisfied Clients+',

    // Stats
    'stat1.value': '15', 'stat1.label': 'Years of Experience',
    'stat2.value': '1',  'stat2.label': 'Branch',
    'stat3.value': '240k','stat3.label': 'Trusted Clients',
    'stat4.value': '98', 'stat4.label': '% Satisfaction Rate',

    // Logos strip
    'logos.title': 'Our Partners & Previous Work',

    // Services section
    'services.badge':    'Our Services',
    'services.title':    'Professional Pest Control Solutions',
    'services.subtitle': 'We provide safe, effective pest-control solutions to protect your premises.',
    'services.all':      'Explore Pest Control',

    // Locations section
    'locations.badge':    'Our Branches',
    'locations.title':    'We Serve You Everywhere',
    'locations.subtitle': 'Our extensive presence ensures our services reach you wherever you are.',
    'locations.all':      'View All Branches',
    'locations.loading':  'Loading branches...',
    'locations.empty':    'No active branches currently.',

    // CTA Banner
    'cta.badge':     'Contact Us Today',
    'cta.title':     'Available 24/7 to Serve You',
    'cta.subtitle':  'Our specialized team responds to your requests as quickly as possible. Request the service now and get a free assessment.',
    'cta.call':      'Call Now',
    'cta.book':      'Book Service',

    // Footer
    'footer.desc':    'The leading public health company in Egypt. We provide comprehensive, globally certified solutions.',
    'footer.company': 'Company',
    'footer.links':   'Quick Links',
    'footer.contact_title': 'Contact Us',
    'footer.address': 'King Faisal St., Giza, Egypt',
    'footer.rights':  '© iKILL 2026 - All Rights Reserved',
    'footer.privacy': 'Privacy Policy',
    'footer.terms':   'Terms of Use',

    // About page
    'about.since':    'Since 2015',
    'about.title':    'iKILL – Leading Public Health Company',
    'about.subtitle': 'Part of the global Rentokil Initial group. The largest public health company in the Middle East & North Africa.',
    'about.partners_title': 'Success Partners & Previous Work',
    'about.values_title':   'Our Core Values',
    'about.desc': 'iKILL was established in 2015 as part of the Rentokil Initial Group, one of the world\'s largest health and public health service companies. Operating in over 80 countries, it serves over 240,000 clients in the region.',
    'about.vision_title': 'Our Vision',
    'about.vision_desc': 'To be the premier provider of integrated public health solutions in Egypt, the Middle East, and Africa.',
    'about.mission_title': 'Our Mission',
    'about.mission_desc': 'Enhance people\'s lives with effective, safe pest-control solutions that improve quality of life.',
    'about.stat1_lbl': 'Years Global Experience',
    'about.stat2_lbl': 'Countries Operated In',
    'about.stat3_lbl': 'Trusted Clients',
    'about.stat4_lbl': 'Satisfaction Rate',
    'about.value1_title': 'Safety First',
    'about.value1_desc': 'We put the safety of our customers and employees at the forefront of our priorities.',
    'about.value2_title': 'Innovation',
    'about.value2_desc': 'We use the latest technologies and scientific solutions in our services.',
    'about.value3_title': 'Sustainability',
    'about.value3_desc': 'We are committed to providing eco-friendly and sustainable solutions.',
    'about.csr_badge': 'Social & Environmental Responsibility',
    'about.csr_title': 'Sustainability at our Core',
    'about.csr_desc': 'We are committed to reducing emissions and using natural resources to develop eco-friendly products and operations. We also provide educational campaigns and community outreach to raise public health awareness.',
    'about.csr_tag1': '"Green Environment" Program',
    'about.csr_tag2': 'Awareness Campaigns',
    'about.csr_tag3': 'Plastic Reduction',
    'about.partners_subtitle': 'A selection of major companies and institutions that have trusted our services.',

    // Contact page
    'contact.title':     'Contact Us',
    'contact.subtitle':  'Our team is ready to answer your inquiries and provide the best solutions.',
    'contact.form.name':     'Full Name',
    'contact.form.phone':    'Phone Number',
    'contact.form.email':    'Email Address',
    'contact.form.address':  'Detailed Address',
    'contact.form.service':  'Service Type',
    'contact.form.message':  'Your Message',
    'contact.form.submit':   'Send Request',
    'contact.social_follow': 'Follow Us on Social Media',

    // Sectors page
    'sectors.title':    'Sectors We Serve',
    'sectors.subtitle': 'We provide specialized solutions for all sectors with the highest quality and safety standards.',
    'sectors.desc': 'Integrated, customized solutions for various industrial, commercial, and service fields.',
    'sectors.food_title': 'Food Establishments',
    'sectors.food_desc': 'Integrated pest-control services for restaurants, hotels, food factories, and supply chains to support public-health compliance.',
    'sectors.edu_title': 'Educational Institutions',
    'sectors.edu_desc': 'Pest-control programs for schools, universities, and nurseries that help maintain a safe, comfortable learning environment.',
    'sectors.health_title': 'Healthcare Sector',
    'sectors.health_desc': 'Specialised pest-control solutions for hospitals, clinics, medical centres, and pharmaceutical factories.',
    'sectors.ind_title': 'Industrial Sector',
    'sectors.ind_desc': 'Advanced protection services for factories, industrial facilities, and warehouses to protect raw materials and finished products from damage.',
    'sectors.retail_title': 'Retail Sector',
    'sectors.retail_desc': 'Comprehensive programs for shopping malls, retail shops, and supermarkets to prevent pest entry and provide clean, welcoming shopping spaces for your customers.',
    'sectors.hosp_title': 'Hospitality Sector',
    'sectors.hosp_desc': 'Protecting your brand and reputation in hotels and resorts through integrated programs that maintain guest comfort and safety.',

    // Services page
    'services.page_title':    'Our Services',
    'services.pest_title':    'Pest Control',

    // Search
    'search.placeholder': 'Search here...',
    'search.admin_hint':  'Admin Panel',

    // Branch info
    'branch.name':          'Head Office - Giza',
    'branch.country':       'Egypt',
    'branch.address_label': 'Address',
    'branch.phone_label':   'Phone',
    'branch.email_label':   'Email',
    'branch.hours_label':   'Working Hours',
    'branch.hours':         '24 Hours / 7 Days',
  }
};

/* =============================================
   STATIC CONTENT TRANSLATOR
   Handles page copy that is not stored in data-i18n attributes.
   ============================================= */
const STATIC_EN_TRANSLATIONS = Object.freeze({
  'حلول آمنة وصديقة للبيئة': 'Safe, eco-friendly solutions',
  'استجابة سريعة على مدار الساعة': 'Rapid response, around the clock',
  'مكافحة الآفات': 'Pest Control',
  'حلول شاملة لمكافحة جميع أنواع الآفات باستخدام أحدث التقنيات وأكثرها أماناً.': 'Comprehensive control for every type of pest, using the latest and safest techniques.',
  'اكتشف المزيد': 'Discover more',
  'الآفات التي نتعامل معها': 'Pests We Handle',
  'نقضي على كل آفة': 'We Eliminate Every Pest',
  'الصراصير': 'Cockroaches', 'القوارض': 'Rodents', 'البعوض': 'Mosquitoes', 'الذباب': 'Flies',
  'النمل الأبيض': 'Termites', 'النمل': 'Ants', 'بق الفراش': 'Bed Bugs', 'الأفاعي': 'Snakes',
  'العقارب': 'Scorpions', 'الطيور': 'Birds', 'العفن': 'Mould', 'وأكثر...': 'And more…',
  'القطاعات': 'Sectors', 'القطاعات التي نخدمها': 'Sectors We Serve',
  'المؤسسات الغذائية': 'Food Establishments', 'الرعاية الصحية': 'Healthcare',
  'قطاع الضيافة': 'Hospitality', 'التعليم': 'Education', 'الصناعة': 'Industry', 'القطاع الصناعي': 'Industrial Sector', 'البيع بالتجزئة': 'Retail',
  'لماذا iKILL': 'Why iKILL', 'ما يميزنا عن الآخرين': 'What Makes Us Different',
  'حلول آمنة 100%': '100% Safe Solutions',
  'نستخدم مواد معتمدة ومرخصة تماماً وآمنة للبشر والحيوانات الأليفة.': 'We use fully approved, licensed materials that are safe for people and pets.',
  'فريق متخصص': 'Specialist Team',
  'خبراء معتمدون دولياً مع أكثر من 15 عاماً من الخبرة في الصحة العامة.': 'Internationally certified experts with more than 15 years of public-health experience.',
  'استجابة فورية 24/7': 'Immediate 24/7 Response',
  'خدمة طوارئ على مدار الساعة لضمان استجابة فورية لحالات الإصابة الحرجة.': 'Emergency support around the clock for a swift response to critical infestations.',
  'العنوان': 'Address', 'شارع الملك فيصل، الجيزة، مصر': 'King Faisal St., Giza, Egypt', 'الفرع الرئيسي': 'Head Office', 'الجيزة': 'Giza',
  'آراء عملائنا': 'Client Testimonials', 'ماذا يقولون عنا': 'What Our Clients Say',
  '“أفضل شركة مكافحة حشرات تعاملت معها. فريق محترف واستجابة سريعة جداً.”': '“The best pest-control company I have worked with. A highly professional team and very fast response.”',
  'أحمد السيد': 'Ahmed El Sayed', 'مدير مطعم': 'Restaurant Manager',
  '“خدمة احترافية للغاية. استخدموا مواد آمنة تماماً مع وجود أطفالنا في البيت.”': '“An exceptionally professional service. They used completely safe materials while our children were at home.”',
  'سارة خالد': 'Sara Khaled', 'ربة منزل': 'Homeowner',
  '“تعاملنا معهم لحماية مستودعاتنا. النتائج مذهلة والفريق محترف جداً.”': '“We worked with them to protect our warehouses. The results were excellent and the team was very professional.”',
  'محمد الشيخ': 'Mohamed El Sheikh', 'مدير عمليات': 'Operations Manager',
  'تم التطوير بواسطة': 'Developed by', 'علي أحمد': 'Ali Ahmed',
  'القائمة': 'Menu', 'استكشف صفحات الموقع': 'Explore the site', 'نظرة عامة': 'Overview',
  'طلبات الخدمة': 'Service Requests', 'شركاء النجاح': 'Success Partners', 'مكافحة القوارض': 'Rodent Control',
  'نبذة عن iKILL': 'About iKILL', 'الاستدامة': 'Sustainability', 'العنوان وساعات العمل': 'Address & Hours',
  'اتصل بالفرع': 'Contact the Branch', 'إرسال طلب خدمة': 'Send a Service Request', 'اتصال مباشر': 'Call Directly',
  '© iKILL 2026 - جميع الحقوق محفوظة': '© iKILL 2026 — All rights reserved',

  'حلول شاملة للصحة العامة': 'Comprehensive Public Health Solutions',
  'نقدم حلولاً متخصصة وآمنة لمكافحة الآفات في المنازل والمنشآت.': 'We provide specialised, safe pest-control solutions for homes and facilities.',
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
  'نشط': 'Active', 'الفرع الرئيسي - الجيزة': 'Head Office – Giza',
  'هاتف': 'Phone', 'البريد الإلكتروني': 'Email', 'ساعات العمل': 'Working Hours',
  '24 ساعة / 7 أيام': '24 Hours / 7 Days', 'المقر الرئيسي': 'Head Office',
  'الاسم الكامل': 'Full Name', 'رقم الهاتف': 'Phone Number', 'العنوان بالتفصيل': 'Detailed Address',
  'نوع الخدمة': 'Service Type', 'خدمة مخصصة': 'Custom Service', 'رسالتك': 'Your Message',
  'معلومات الاتصال': 'Contact Information', 'الهاتف': 'Phone', 'متوفر 24/7': 'Available 24/7',
  'طلب خدمة': 'Service Request', 'بيانات التواصل': 'Contact Details', 'تفاصيل الطلب': 'Request Details', 'مراجعة وإرسال': 'Review & Submit',
  'سنستخدمها للتواصل معك بخصوص طلبك': 'We will use these details to contact you about your request.',
  'أخبرنا بالموقع ونوع الخدمة المطلوبة': 'Tell us the location and the service you need.',
  'نلتزم بالحفاظ على خصوصية بياناتك وسنتواصل معك في أقرب وقت.': 'We protect your privacy and will contact you as soon as possible.',
  'طلب خدمة آمن وسريع': 'Secure, Fast Service Request', 'متابعة سريعة': 'Fast Follow-up',
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
        'index.html': 'iKILL | مكافحة الآفات في مصر',
        'services.html': 'خدمات مكافحة الآفات | iKILL مصر',
        'sectors.html': 'حلول مكافحة الآفات للقطاعات | iKILL مصر',
        'about.html': 'من نحن | iKILL Pest Control Services مصر',
        'locations.html': 'فروع iKILL وعنوان الشركة | مكافحة الآفات في مصر',
        'contact.html': 'اتصل بـ iKILL | طلب خدمة مكافحة آفات'
      },
      en: {
        'index.html': 'iKILL | Pest Control Services in Egypt',
        'services.html': 'Pest Control Services | iKILL Egypt',
        'sectors.html': 'Pest Control Solutions by Sector | iKILL Egypt',
        'about.html': 'About Us | iKILL Pest Control Services Egypt',
        'locations.html': 'iKILL Locations & Address | Pest Control in Egypt',
        'contact.html': 'Contact iKILL | Request Pest Control Service'
      }
    };
    if (titles[lang][file]) document.title = titles[lang][file];
  }
};

/* =============================================
   LANGUAGE MANAGER
   ============================================= */
const LangManager = {
  current: 'ar',

  init() {
    const saved = localStorage.getItem('ikill-lang') || 'ar';
    this.set(saved, false);
  },

  set(lang, animate = true) {
    this.current = lang;
    localStorage.setItem('ikill-lang', lang);

    // Update html attributes
    document.documentElement.lang = lang;
    document.documentElement.dir  = lang === 'ar' ? 'rtl' : 'ltr';

    // Update all translated elements
    document.querySelectorAll('[data-i18n]').forEach(el => {
      const key = el.getAttribute('data-i18n');
      const val = TRANSLATIONS[lang][key];
      if (val !== undefined) {
        if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
          el.placeholder = val;
        } else {
          el.textContent = val;
        }
      }
    });

    // Update placeholder-only translations
    document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
      const key = el.getAttribute('data-i18n-placeholder');
      const val = TRANSLATIONS[lang][key];
      if (val !== undefined) el.placeholder = val;
    });

    // Translate the remaining static page copy and form placeholders.
    StaticContentTranslator.set(lang);

    // Update lang buttons
    document.querySelectorAll('.lang-btn').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.lang === lang);
    });

    // Update search placeholder
    const searchInput = document.getElementById('global-search-input');
    if (searchInput) {
      searchInput.placeholder = lang === 'ar' ? 'ابحث هنا...' : 'Search here...';
    }

    // Animate content swap
    if (animate) {
      document.body.style.opacity = '0.7';
      document.body.style.transform = 'scale(0.99)';
      setTimeout(() => {
        document.body.style.opacity = '';
        document.body.style.transform = '';
        document.body.style.transition = 'opacity 0.3s ease, transform 0.3s ease';
      }, 50);
    }
  },

  toggle() {
    this.set(this.current === 'ar' ? 'en' : 'ar');
  },

  t(key) {
    return TRANSLATIONS[this.current][key] || key;
  }
};

/* =============================================
   THEME MANAGER (Dark / Light Mode)
   ============================================= */
const ThemeManager = {
  current: 'light',

  init() {
    const saved = localStorage.getItem('ikill-theme');
    const prefDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const theme = saved || (prefDark ? 'dark' : 'light');
    this.set(theme, false);

    // Listen for OS preference changes
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', e => {
      if (!localStorage.getItem('ikill-theme')) {
        this.set(e.matches ? 'dark' : 'light', true);
      }
    });
  },

  set(theme, animate = true) {
    this.current = theme;
    localStorage.setItem('ikill-theme', theme);
    document.documentElement.setAttribute('data-theme', theme);

    // Update toggle checkboxes
    document.querySelectorAll('.theme-checkbox').forEach(cb => {
      cb.checked = theme === 'dark';
    });

    // Update icons
    document.querySelectorAll('.theme-icon-moon').forEach(el => {
      el.style.display = theme === 'dark' ? 'inline-block' : 'none';
    });
    document.querySelectorAll('.theme-icon-sun').forEach(el => {
      el.style.display = theme === 'light' ? 'inline-block' : 'none';
    });

    // Switch to the white-detail version of the logo on dark surfaces.
    // The same asset is also used as the favicon so the browser tab remains legible.
    const brandLogo = theme === 'dark' ? 'img/ikill-logo-dark.png' : 'img/ikill-logo.png';
    document.querySelectorAll('img[src*="ikill-logo"]').forEach(img => {
      // The footer is permanently dark, so it always uses the white-detail wordmark.
      img.src = img.closest('.ikill-footer') ? 'img/ikill-logo-dark.png' : brandLogo;
    });
    const favicon = document.getElementById('favicon');
    if (favicon) favicon.href = `${brandLogo}?theme=${theme}`;
  }, 

  toggle() {
    this.set(this.current === 'light' ? 'dark' : 'light');
  }
};

/* =============================================
   SCROLL ANIMATIONS (Intersection Observer)
   ============================================= */
const AnimationManager = {
  observer: null,

  init() {
    const options = {
      threshold: 0.12,
      rootMargin: '0px 0px -40px 0px'
    };

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
          // For stagger, also mark parent visible
          if (entry.target.classList.contains('animate-stagger')) {
            entry.target.classList.add('visible');
          }
          // Unobserve after animation
          this.observer.unobserve(entry.target);
        }
      });
    }, options);

    // Observe all animated elements
    document.querySelectorAll(
      '.animate-fade-up, .animate-stagger, .animate-scale, .animate-slide, .text-underline-reveal'
    ).forEach(el => this.observer.observe(el));
  },

  refresh() {
    // Re-scan for newly added elements
    document.querySelectorAll(
      '.animate-fade-up:not(.visible), .animate-stagger:not(.visible), .animate-scale:not(.visible), .animate-slide:not(.visible)'
    ).forEach(el => this.observer.observe(el));
  }
};

/* =============================================
   COUNTER ANIMATION
   ============================================= */
const CounterManager = {
  init() {
    const counters = document.querySelectorAll('[data-counter]');
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this.animate(entry.target);
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.5 });

    counters.forEach(el => observer.observe(el));
  },

  animate(el) {
    const rawTarget = el.getAttribute('data-counter');
    const suffix = rawTarget.replace(/[\d.]/g, ''); // e.g. 'k', '%', '+'
    const target = parseFloat(rawTarget);
    const duration = 1800;
    const start = performance.now();

    const tick = (now) => {
      const elapsed = now - start;
      const progress = Math.min(elapsed / duration, 1);
      // Ease-out cubic
      const eased = 1 - Math.pow(1 - progress, 3);
      const current = target * eased;

      el.textContent = (Number.isInteger(target) ? Math.round(current) : current.toFixed(1)) + suffix;

      if (progress < 1) requestAnimationFrame(tick);
    };

    requestAnimationFrame(tick);
  }
};

/* =============================================
   NAVBAR SCROLL EFFECT
   ============================================= */
const NavbarManager = {
  init() {
    const navbar = document.getElementById('ikill-navbar');
    if (!navbar) return;

    window.addEventListener('scroll', () => {
      navbar.classList.toggle('scrolled', window.scrollY > 24);
    }, { passive: true });
  }
};

/* =============================================
   HERO PARTICLES
   ============================================= */
const ParticleManager = {
  init() {
    const container = document.querySelector('.hero-particles');
    if (!container) return;

    const count = 20;
    for (let i = 0; i < count; i++) {
      const span = document.createElement('span');
      const size = Math.random() * 6 + 3;
      span.style.cssText = `
        width: ${size}px;
        height: ${size}px;
        --x: ${Math.random() * 100}%;
        --duration: ${Math.random() * 14 + 8}s;
        --delay: ${Math.random() * 12}s;
        opacity: ${Math.random() * 0.5 + 0.1};
      `;
      container.appendChild(span);
    }
  }
};

/* =============================================
   MOBILE MENU
   ============================================= */
const MobileMenu = {
  isOpen: false,

  init() {
    const toggle = document.getElementById('mobile-menu-toggle');
    const menu   = document.getElementById('mobile-menu');
    const close  = document.getElementById('mobile-menu-close');

    if (!toggle || !menu) return;

    toggle.addEventListener('click', () => this.open(menu, toggle));
    if (close) close.addEventListener('click', () => this.closeMenu(menu, toggle));

    // Close on outside click
    menu.addEventListener('click', (e) => {
      if (e.target === menu) this.closeMenu(menu, toggle);
    });
  },

  open(menu, toggle) {
    menu.classList.add('open');
    toggle.setAttribute('aria-expanded', 'true');
    document.body.style.overflow = 'hidden';
    this.isOpen = true;
  },

  closeMenu(menu, toggle) {
    menu.classList.remove('open');
    toggle.setAttribute('aria-expanded', 'false');
    document.body.style.overflow = '';
    this.isOpen = false;
  }
};

/* =============================================
   SUPABASE CLIENT (shared)
   ============================================= */
const BackendManager = {
  db: null,
  initialized: false,

  async waitForDb(timeout = 8000) {
    if (window.db) return window.db;
    return new Promise(resolve => {
      let waited = 0;
      const interval = setInterval(() => {
        waited += 100;
        if (window.db || waited >= timeout) {
          clearInterval(interval);
          resolve(window.db || null);
        }
      }, 100);
    });
  }
};

/* =============================================
   DYNAMIC SETTINGS LOADER (index.html)
   ============================================= */
const SettingsLoader = {
  async init() {
    const db = await BackendManager.waitForDb();
    if (!db) return;

    db.table('brand_settings').record('global').subscribe((doc) => {
      if (!doc.exists) return;
      const data = doc.data();

      // Stats. The business experience figure is set to 15 years site-wide.
      const fields = ['stat1', 'stat2', 'stat3', 'stat4'];
      fields.forEach(f => {
        const valEl = document.getElementById(`${f}-val`);
        const lblEl = document.getElementById(`${f}-lbl`);
        const value = f === 'stat1' ? '15' : data[`${f}Value`];
        if (valEl && value) {
          valEl.setAttribute('data-counter', value);
          valEl.textContent = value;
        }
        if (lblEl && data[`${f}Label`]) lblEl.textContent = data[`${f}Label`];
      });

      // Contact info. The published company email is always info@ikill.net.
      ['phone', 'address'].forEach(field => {
        if (!data[field]) return;
        document.querySelectorAll(`[data-contact="${field}"]`).forEach(el => {
          el.textContent = data[field];
          if (field === 'phone') {
            const anchor = el.closest('a') || (el.tagName === 'A' ? el : null);
            if (anchor) anchor.href = `tel:${data[field].replace(/\s+/g, '')}`;
          }
        });
      });
      applyCompanyEmail();
    });
  }
};

/* =============================================
   DYNAMIC BRANCHES LOADER
   ============================================= */
const BranchesLoader = {
  async init(containerId, maxItems = 999, groupByCountry = false) {
    const container = document.getElementById(containerId);
    if (!container) return;

    const db = await BackendManager.waitForDb();
    if (!db) {
      container.innerHTML = '<div class="col-span-full text-center py-10" style="color:var(--text-muted)">تعذّر الاتصال بقاعدة البيانات.</div>';
      return;
    }

    db.table('company_branches').where('status', '==', 'active').subscribe(snapshot => {
      container.innerHTML = '';
      const docs = [];
      snapshot.forEach(doc => docs.push({ id: doc.id, ...doc.data() }));

      if (docs.length === 0) {
        container.innerHTML = `<div class="col-span-full text-center py-10" style="color:var(--text-muted)" data-i18n="locations.empty">${LangManager.t('locations.empty')}</div>`;
        return;
      }

      if (groupByCountry) {
        // Group by country for locations page
        const countries = {};
        docs.forEach(d => {
          const c = d.countryAr || 'أخرى';
          if (!countries[c]) countries[c] = [];
          countries[c].push(d);
        });

        Object.entries(countries).forEach(([country, branches]) => {
          const card = document.createElement('div');
          card.className = 'card animate-fade-up';
          card.innerHTML = `
            <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:1rem;">
              <span style="font-weight:700;font-size:1.05rem;">${country}</span>
              ${country === 'مصر' || country === 'Egypt'
                ? '<span style="font-size:0.72rem;padding:0.2rem 0.7rem;background:var(--green-50);color:var(--green-700);border-radius:999px;font-weight:700;">الرئيسي</span>'
                : ''}
            </div>
            <div style="display:flex;flex-direction:column;gap:0.6rem;">
              ${branches.map(b => `
                <div style="display:flex;gap:0.75rem;font-size:0.88rem;">
                  <span style="font-weight:600;color:var(--text-secondary);min-width:90px;">${b.nameAr}:</span>
                  <span style="color:var(--text-muted);">${b.phone || 'نشط'}</span>
                </div>
              `).join('')}
            </div>
          `;
          container.appendChild(card);
        });
      } else {
        // Teaser grid for home page
        const limited = docs.slice(0, maxItems);
        limited.forEach(branch => {
          const div = document.createElement('div');
          div.className = 'location-teaser-card animate-fade-up';
          div.style.cssText = `
            display:flex;align-items:center;gap:1rem;
            background:var(--bg-card);border:1px solid var(--border-color);
            border-radius:var(--radius-xl);padding:1.1rem 1.25rem;
            transition:all 0.3s ease;cursor:default;
          `;
          div.innerHTML = `
            <div style="width:40px;height:40px;border-radius:50%;background:var(--green-50);display:flex;align-items:center;justify-content:center;flex-shrink:0;">
              <i class="fas fa-map-marker-alt" style="color:var(--green-400);font-size:1rem;"></i>
            </div>
            <div>
              <div style="font-weight:700;color:var(--text-primary);">${branch.nameAr}</div>
              <div style="font-size:0.78rem;color:var(--text-muted);">${branch.countryAr || ''}</div>
            </div>
          `;
          div.addEventListener('mouseenter', () => {
            div.style.borderColor = 'var(--green-400)';
            div.style.transform = 'translateY(-4px)';
            div.style.boxShadow = 'var(--shadow-md)';
          });
          div.addEventListener('mouseleave', () => {
            div.style.borderColor = 'var(--border-color)';
            div.style.transform = '';
            div.style.boxShadow = '';
          });
          container.appendChild(div);
        });
      }

      // Re-run animations
      AnimationManager.refresh();
    });
  }
};

/* =============================================
   TILT EFFECT (3D cards)
   ============================================= */
const TiltEffect = {
  init(selector = '.card-tilt') {
    document.querySelectorAll(selector).forEach(card => {
      card.addEventListener('mousemove', e => {
        const rect = card.getBoundingClientRect();
        const cx = rect.left + rect.width / 2;
        const cy = rect.top + rect.height / 2;
        const dx = (e.clientX - cx) / (rect.width / 2);
        const dy = (e.clientY - cy) / (rect.height / 2);
        card.style.transform = `perspective(800px) rotateX(${-dy * 6}deg) rotateY(${dx * 6}deg) translateZ(8px)`;
      });
      card.addEventListener('mouseleave', () => {
        card.style.transform = '';
        card.style.transition = 'transform 0.5s ease';
        setTimeout(() => { card.style.transition = ''; }, 500);
      });
    });
  }
};

/* =============================================
   GLOBAL SEARCH MANAGER
   ============================================= */
const SearchManager = {
  ITEMS: [
    { key: 'pest',     icon: 'fa-bug',           ar: 'مكافحة الآفات',               en: 'Pest Control',             url: 'services.html#pest' },
    { key: 'about',    icon: 'fa-info-circle',   ar: 'من نحن',                    en: 'About Us',                 url: 'about.html' },
    { key: 'contact',  icon: 'fa-phone-alt',     ar: 'اتصل بنا',                 en: 'Contact Us',               url: 'contact.html' },
    { key: 'branches', icon: 'fa-map-marker-alt',ar: 'فروعنا',                    en: 'Our Branches',             url: 'locations.html' },
    { key: 'sectors',  icon: 'fa-building',      ar: 'القطاعات',                  en: 'Sectors',                  url: 'sectors.html' },
    { key: 'cockroach',icon: 'fa-bug',           ar: 'مكافحة الصراصير',           en: 'Cockroach Control',        url: 'services.html#cockroach' },
    { key: 'rodent',   icon: 'fa-paw',           ar: 'مكافحة القوارض',             en: 'Rodent Control',           url: 'services.html#rodent' },
    { key: 'mosquito', icon: 'fa-mosquito',      ar: 'مكافحة البعوض',              en: 'Mosquito Control',         url: 'services.html#mosquito' },
    { key: 'hotel',    icon: 'fa-hotel',         ar: 'قطاع الضيافة',              en: 'Hospitality Sector',       url: 'sectors.html#hotel' },
    { key: 'hospital', icon: 'fa-hospital',      ar: 'الرعاية الصحية',            en: 'Healthcare',               url: 'sectors.html#health' },
  ],

  // These keywords and the official company email only expose the login route;
  // they do not bypass Supabase authentication in any way.
  ADMIN_TRIGGERS: ['admin', 'ادمن', 'لوحة التحكم', 'dashboard', 'panel', 'دخول', 'login', 'تسجيل'],
  ADMIN_EMAILS: [COMPANY_EMAIL],

  init() {
    const input    = document.getElementById('global-search-input');
    const dropdown = document.getElementById('search-dropdown');
    if (!input || !dropdown) return;

    input.addEventListener('input', () => this.handleInput(input, dropdown));
    input.addEventListener('focus', () => { if (input.value) dropdown.classList.add('open'); });

    // Close on outside click
    document.addEventListener('click', (e) => {
      if (!e.target.closest('.global-search-wrap')) {
        dropdown.classList.remove('open');
      }
    });

    // Keyboard navigation
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        const first = dropdown.querySelector('.search-result-item');
        if (first) window.location.href = first.href;
      }
      if (e.key === 'Escape') {
        dropdown.classList.remove('open');
        input.blur();
      }
    });
  },

  handleInput(input, dropdown) {
    const query = input.value.trim().toLowerCase();
    dropdown.innerHTML = '';

    if (!query) {
      dropdown.classList.remove('open');
      return;
    }

    // Check for an admin keyword or the official company email.
    // Support both a pasted email and a pasted mailto: URL.
    const normalizedQuery = query.replace(/^mailto:/, '').trim();
    const isAdminQuery =
      this.ADMIN_EMAILS.includes(normalizedQuery) ||
      this.ADMIN_TRIGGERS.some(t => t.includes(normalizedQuery) || normalizedQuery.includes(t));
    if (isAdminQuery) {
      dropdown.innerHTML = `
        <a href="admin-login.html" class="search-result-item" style="border-color:rgba(76,175,80,0.3);background:rgba(76,175,80,0.05);">
          <i class="fas fa-lock" style="background:rgba(76,175,80,0.15);color:var(--green-600);"></i>
          <div>
            <div style="font-weight:700;color:var(--green-700);">${LangManager.current === 'ar' ? 'لوحة تحكم الموقع' : 'Admin Dashboard'}</div>
            <div style="font-size:0.75rem;color:var(--text-muted);">${LangManager.current === 'ar' ? 'اضغط لتسجيل الدخول' : 'Click to login'}</div>
          </div>
        </a>`;
      dropdown.classList.add('open');
      return;
    }

    const lang = LangManager.current;
    const results = this.ITEMS.filter(item => {
      const text = lang === 'ar' ? item.ar : item.en;
      return text.toLowerCase().includes(query) || item.key.includes(query);
    }).slice(0, 6);

    if (results.length === 0) {
      dropdown.innerHTML = `<div class="search-result-item" style="cursor:default;color:var(--text-muted);"><i class="fas fa-search-minus"></i> ${lang === 'ar' ? 'لا توجد نتائج' : 'No results found'}</div>`;
    } else {
      results.forEach(item => {
        const label = lang === 'ar' ? item.ar : item.en;
        const a = document.createElement('a');
        a.href = item.url;
        a.className = 'search-result-item';
        a.innerHTML = `<i class="fas ${item.icon}"></i><span>${label}</span>`;
        dropdown.appendChild(a);
      });
    }

    dropdown.classList.add('open');
  }
};

/* =============================================
   POP-UP SITE NAVIGATION
   ============================================= */
const SiteMenu = {
  init() {
    const toggle = document.getElementById('site-menu-toggle');
    const popover = document.getElementById('site-menu-popover');
    const close = document.getElementById('site-menu-close');
    if (!toggle || !popover) return;

    // The navbar uses blur effects, which can create a positioning container.
    // Move the popover to body so it is always positioned against the viewport,
    // not clipped or pushed off-screen in RTL/LTR mobile layouts.
    document.body.appendChild(popover);
    popover.classList.add('portal-popover');

    const positionPopover = () => {
      const rect = toggle.getBoundingClientRect();
      const isPhone = window.matchMedia('(max-width: 767px)').matches;
      if (isPhone) {
        popover.style.top = `${Math.max(8, rect.bottom + 8)}px`;
        popover.style.left = '10px';
        popover.style.right = '10px';
        popover.style.width = 'auto';
        popover.style.maxWidth = 'none';
      } else {
        const width = Math.min(820, window.innerWidth - 24);
        popover.style.top = `${rect.bottom + 12}px`;
        popover.style.left = `${Math.max(12, Math.min(rect.left, window.innerWidth - width - 12))}px`;
        popover.style.right = 'auto';
        popover.style.width = `${width}px`;
        popover.style.maxWidth = `${width}px`;
      }
    };

    const setOpen = (open) => {
      if (open) positionPopover();
      popover.classList.toggle('open', open);
      popover.setAttribute('aria-hidden', String(!open));
      toggle.setAttribute('aria-expanded', String(open));
    };

    toggle.addEventListener('click', (event) => {
      event.stopPropagation();
      setOpen(!popover.classList.contains('open'));
    });
    close && close.addEventListener('click', () => setOpen(false));
    popover.querySelectorAll('a').forEach(link => link.addEventListener('click', () => setOpen(false)));
    document.addEventListener('click', (event) => {
      if (!event.target.closest('.site-menu-wrap') && !event.target.closest('#site-menu-popover')) setOpen(false);
    });
    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape') setOpen(false);
    });
    window.addEventListener('resize', () => {
      if (popover.classList.contains('open')) positionPopover();
    }, { passive: true });
  }
};

/* =============================================
   PARTNERS CAROUSEL
   Slow, seamless auto-scroll with buttons, mouse drag, touch swipe and keyboard support.
   ============================================= */
const PartnersCarousel = {
  init() {
    const viewport = document.getElementById('partners-marquee');
    const track = viewport?.querySelector('.marquee-track');
    const prev = document.getElementById('partners-prev');
    const next = document.getElementById('partners-next');
    const carousel = viewport?.closest('.partners-carousel');
    if (!viewport || !track || track.children.length < 6) return;

    const setCount = Math.floor(track.children.length / 3);
    let loopWidth = 0;
    let dragStartX = 0;
    let dragStartScroll = 0;
    let isDragging = false;
    let pauseUntil = 0;
    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    const calculateLoopWidth = () => {
      const first = track.children[0];
      const nextSet = track.children[setCount];
      if (!first || !nextSet) return;
      loopWidth = nextSet.offsetLeft - first.offsetLeft;
      if (loopWidth > 0) {
        if (viewport.scrollLeft < 2) viewport.scrollLeft = loopWidth;
        carousel?.classList.add('is-interactive');
      }
    };

    const pause = (milliseconds = 2800) => { pauseUntil = Date.now() + milliseconds; };
    const normalisePosition = () => {
      if (!loopWidth) return;
      if (viewport.scrollLeft >= loopWidth * 2) viewport.scrollLeft -= loopWidth;
      if (viewport.scrollLeft <= 0) viewport.scrollLeft += loopWidth;
    };
    const moveBy = (amount) => {
      pause(4200);
      viewport.scrollBy({ left: amount, behavior: 'smooth' });
    };

    prev?.addEventListener('click', () => moveBy(-330));
    next?.addEventListener('click', () => moveBy(330));
    viewport.addEventListener('keydown', (event) => {
      if (event.key === 'ArrowRight') { event.preventDefault(); moveBy(330); }
      if (event.key === 'ArrowLeft') { event.preventDefault(); moveBy(-330); }
    });
    viewport.addEventListener('wheel', () => pause(5000), { passive: true });
    viewport.addEventListener('mouseenter', () => pause(7000));

    viewport.addEventListener('pointerdown', (event) => {
      isDragging = true;
      dragStartX = event.clientX;
      dragStartScroll = viewport.scrollLeft;
      viewport.classList.add('is-dragging');
      pause(7000);
      viewport.setPointerCapture?.(event.pointerId);
    });
    viewport.addEventListener('pointermove', (event) => {
      if (!isDragging) return;
      const delta = event.clientX - dragStartX;
      if (Math.abs(delta) > 3) {
        viewport.scrollLeft = dragStartScroll - delta;
        event.preventDefault();
      }
    });
    const endDrag = () => {
      if (!isDragging) return;
      isDragging = false;
      viewport.classList.remove('is-dragging');
      pause(3500);
      normalisePosition();
    };
    viewport.addEventListener('pointerup', endDrag);
    viewport.addEventListener('pointercancel', endDrag);
    window.addEventListener('resize', calculateLoopWidth, { passive: true });

    requestAnimationFrame(() => requestAnimationFrame(calculateLoopWidth));
    if (!reducedMotion) {
      let autoRemainder = 0;
      const tick = () => {
        if (!document.hidden && !isDragging && Date.now() > pauseUntil && loopWidth) {
          // ~29px/sec: calm enough to read each mark, fast enough to stay visibly alive.
          // Keep fractional movement in a buffer for browsers that round scrollLeft to pixels.
          autoRemainder += 0.48;
          const movement = Math.floor(autoRemainder);
          if (movement) {
            viewport.scrollLeft += movement;
            autoRemainder -= movement;
            normalisePosition();
          }
        }
        requestAnimationFrame(tick);
      };
      requestAnimationFrame(tick);
    }
  }
};

/* =============================================
   MAIN INIT
   ============================================= */
document.addEventListener('DOMContentLoaded', () => {
  // Core systems
  applyCompanyEmail();
  ThemeManager.init();
  LangManager.init();
  NavbarManager.init();
  AnimationManager.init();
  CounterManager.init();
  ParticleManager.init();
  MobileMenu.init();
  TiltEffect.init();
  SearchManager.init();
  SiteMenu.init();
  PartnersCarousel.init();

  // Wire up theme toggles
  document.querySelectorAll('.theme-toggle-btn, [data-theme-toggle]').forEach(btn => {
    btn.addEventListener('click', () => ThemeManager.toggle());
  });

  document.querySelectorAll('.theme-checkbox').forEach(cb => {
    cb.addEventListener('change', () => ThemeManager.toggle());
  });

  // Wire up language buttons
  document.querySelectorAll('.lang-btn').forEach(btn => {
    btn.addEventListener('click', () => LangManager.set(btn.dataset.lang));
  });

  // Supabase-dependent loaders (only on pages that need them)
  if (document.getElementById('stat1-val')) {
    SettingsLoader.init();
  }
  if (document.getElementById('locations-teaser-container')) {
    BranchesLoader.init('locations-teaser-container', 6);
  }
  if (document.getElementById('branches-container')) {
    BranchesLoader.init('branches-container', 999, true);
  }

  // Analytics
  if (window._ikillAnalyticsLoaded) return;
  window._ikillAnalyticsLoaded = true;
});

// Expose globally
window.ThemeManager = ThemeManager;
window.LangManager  = LangManager;
