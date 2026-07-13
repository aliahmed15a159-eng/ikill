from pathlib import Path
from html import escape
import json,re
root=Path('/home/user/uploads')
domain='https://ikill.net'
common_keywords='''iKILL, اي كيل, ايكيل, iKILL Pest Control Services, مكافحة الحشرات, شركة مكافحة حشرات, مكافحة آفات, مكافحة الآفات مصر, مكافحة الحشرات مصر, شركة مكافحة حشرات في مصر, مكافحة الصراصير, مكافحة النمل الأبيض, مكافحة النمل, مكافحة البق, مكافحة بق الفراش, مكافحة الفئران, مكافحة القوارض, مكافحة البعوض, مكافحة الذباب, مكافحة البراغيث, مكافحة العناكب, مكافحة العقارب, مكافحة الثعابين, مكافحة الطيور, مكافحة الناموس, إبادة الحشرات, التخلص من الحشرات, رش حشرات, رش صراصير, رش مبيدات, مكافحة حشرات المنازل, مكافحة حشرات الشركات, مكافحة حشرات المطاعم, مكافحة حشرات الفنادق, مكافحة حشرات المصانع, مكافحة حشرات المدارس, مكافحة حشرات المستشفيات, تعقيم, تطهير, تعقيم المنازل, تعقيم الشركات, مكافحة الجراثيم, مكافحة الفيروسات, نظافة وتعطير, سلامة الغذاء, مكافحة آفات الأغذية, الصحة العامة, خدمات الصحة العامة, مكافحة آفات القاهرة, مكافحة حشرات الجيزة, مكافحة حشرات فيصل, مكافحة حشرات مصر الجديدة, مكافحة حشرات أكتوبر, مكافحة حشرات التجمع, مكافحة حشرات المعادي, مكافحة حشرات مدينة نصر, مكافحة حشرات الشيخ زايد, مكافحة آفات القاهرة الكبرى, pest control Egypt, pest control Cairo, pest control Giza, exterminator Egypt, cockroach control, termite control Egypt, rodent control, bed bug control, mosquito control, fumigation Egypt, sanitization services Egypt, disinfection services Egypt, food safety services, hygiene services, public health services, eco friendly pest control, integrated pest management, IPM Egypt, iKILL Egypt, ikill.net'''
pages={
'index.html':('iKILL | مكافحة الآفات والتعقيم وسلامة الغذاء في مصر','iKILL لخدمات مكافحة الآفات والتعقيم وسلامة الغذاء والنظافة. حلول آمنة واحترافية للمنازل والشركات والمنشآت في مصر.', 'خدمات مكافحة الحشرات للمنازل والشركات، حلول الصحة العامة، طلب خدمة مكافحة آفات'),
'services.html':('خدمات مكافحة الآفات والتعقيم | iKILL مصر','اكتشف خدمات iKILL المتكاملة لمكافحة الآفات والجراثيم وسلامة الغذاء والنظافة والتعطير في مصر.', 'خدمات مكافحة الصراصير والقوارض والبق، التعقيم والتطهير، سلامة الغذاء'),
'sectors.html':('حلول مكافحة الآفات للقطاعات | iKILL مصر','حلول مكافحة آفات وصحة عامة متخصصة للمطاعم والفنادق والمستشفيات والمدارس والمصانع والمتاجر في مصر.', 'مكافحة آفات المطاعم، مكافحة حشرات الفنادق، مكافحة آفات المصانع، التعقيم للمستشفيات'),
'about.html':('من نحن | iKILL Pest Control Services مصر','تعرف على iKILL وخبرتنا في تقديم حلول مكافحة الآفات والصحة العامة الآمنة والمستدامة في مصر.', 'شركة iKILL، خبرة 15 عاماً، مكافحة آفات مستدامة، حلول صحة عامة مصر'),
'locations.html':('فروع iKILL وعنوان الشركة | مكافحة الآفات في مصر','بيانات الفرع الرئيسي لشركة iKILL: شارع الملك فيصل، الجيزة، مصر. اتصل بنا لطلب خدمات مكافحة الآفات والصحة العامة.', 'عنوان iKILL، فرع iKILL الجيزة، شركة مكافحة حشرات فيصل، مكافحة آفات الجيزة'),
'contact.html':('اتصل بـ iKILL | طلب خدمة مكافحة آفات','تواصل مع iKILL عبر info@ikill.com.eg أو الهاتف لطلب خدمات مكافحة الآفات والتعقيم وسلامة الغذاء في مصر.', 'رقم شركة مكافحة حشرات، ايميل iKILL، طلب مكافحة آفات، حجز تعقيم'),
'privacy-policy.html':('سياسة الخصوصية | iKILL','تعرف على كيفية تعامل iKILL مع البيانات الشخصية وطلبات التواصل عبر موقع ikill.net.', 'سياسة الخصوصية iKILL، خصوصية مكافحة الآفات'),
'terms.html':('شروط الاستخدام | iKILL','شروط استخدام موقع iKILL لخدمات مكافحة الآفات والصحة العامة في مصر.', 'شروط استخدام iKILL، خدمات مكافحة الآفات مصر'),
}
organization={
 '@context':'https://schema.org', '@type':'ProfessionalService',
 'name':'iKILL Pest Control Services', 'alternateName':'iKILL',
 'url':domain, 'logo':domain+'/img/ikill-logo.png', 'image':domain+'/img/eco-environment-hero.jpg',
 'email':'info@ikill.com.eg', 'telephone':'+201020019042',
 'description':'خدمات مكافحة الآفات والتعقيم وسلامة الغذاء والنظافة والصحة العامة في مصر.',
 'address':{'@type':'PostalAddress','streetAddress':'شارع الملك فيصل','addressLocality':'الجيزة','addressCountry':'EG'},
 'areaServed':[{'@type':'Country','name':'Egypt'},{'@type':'City','name':'Cairo'},{'@type':'City','name':'Giza'}],
 'knowsAbout':['Pest control','Integrated pest management','Sanitization','Food safety','Public health'],
 'contactPoint':{'@type':'ContactPoint','telephone':'+201020019042','contactType':'customer service','email':'info@ikill.com.eg','availableLanguage':['ar','en']}
}
for filename,(title,desc,extra) in pages.items():
 p=root/filename;s=p.read_text()
 # Regeneration safe: strip old canonical and prior structured SEO insert.
 s=re.sub(r'\s*<link rel="canonical" href="[^"]+">','',s)
 s=re.sub(r'\n?\s*<!-- SEO:START -->.*?<!-- SEO:END -->\n?', '\n', s, flags=re.S)
 # Titles should never be replaced by client i18n with a one-word label.
 s=re.sub(r'<title(?:\s+[^>]*)?>.*?</title>',f'<title>{escape(title)}</title>',s,count=1,flags=re.S)
 s=re.sub(r'<meta name="description" content="[^"]*">',f'<meta name="description" content="{escape(desc, quote=True)}">',s,count=1)
 path='/' if filename=='index.html' else '/'+filename
 url=domain+path
 schema=organization.copy(); schema['@id']=domain+'/#organization'
 webpage={'@context':'https://schema.org','@type':'WebPage','name':title,'url':url,'inLanguage':'ar-EG','isPartOf':{'@id':domain+'/#organization'}}
 seo=f'''    <!-- SEO:START -->
    <meta name="robots" content="index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1">
    <meta name="googlebot" content="index, follow">
    <meta name="author" content="iKILL Pest Control Services">
    <meta name="keywords" content="{escape(extra+', '+common_keywords, quote=True)}">
    <meta name="language" content="Arabic">
    <link rel="canonical" href="{url}">
    <link rel="alternate" hreflang="ar" href="{url}">
    <link rel="alternate" hreflang="x-default" href="{url}">
    <link rel="manifest" href="site.webmanifest">
    <meta name="theme-color" content="#087149">
    <meta property="og:locale" content="ar_EG">
    <meta property="og:type" content="website">
    <meta property="og:site_name" content="iKILL Pest Control Services">
    <meta property="og:title" content="{escape(title, quote=True)}">
    <meta property="og:description" content="{escape(desc, quote=True)}">
    <meta property="og:url" content="{url}">
    <meta property="og:image" content="{domain}/img/eco-environment-hero.jpg">
    <meta property="og:image:alt" content="iKILL Pest Control Services">
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="{escape(title, quote=True)}">
    <meta name="twitter:description" content="{escape(desc, quote=True)}">
    <meta name="twitter:image" content="{domain}/img/eco-environment-hero.jpg">
    <script type="application/ld+json">{json.dumps(schema,ensure_ascii=False,separators=(',',':'))}</script>
    <script type="application/ld+json">{json.dumps(webpage,ensure_ascii=False,separators=(',',':'))}</script>
    <!-- SEO:END -->'''
 # metadata immediately follows the description.
 desc_tag=f'<meta name="description" content="{escape(desc, quote=True)}">'
 if desc_tag not in s: raise SystemExit('description not present '+filename)
 s=s.replace(desc_tag,desc_tag+'\n'+seo,1)
 p.write_text(s)
print('SEO metadata added to',len(pages),'pages')
