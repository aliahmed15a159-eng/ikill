import 'notifications_screen.dart';
import 'dart:async';
import 'push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'backend.dart';
import 'content.dart';
import 'request_form.dart';
import 'admin.dart';
import 'technician_tasks.dart';
import 'documents_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final content = await SiteContent.load();
  final preferences = await SharedPreferences.getInstance();
  await Backend.initialize();
  runApp(IkillApp(content: content, preferences: preferences));
  if (Backend.ready) unawaited(PushService.start().catchError((Object _) {}));
}

const brand = Color(0xFF15803D);

Future<void> openLink(BuildContext context, String url) async {
  try {
    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر فتح الرابط / Could not open link')));
    }
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر فتح الرابط / Could not open link')));
  }
}

class IkillApp extends StatefulWidget {
  final SiteContent content;
  final SharedPreferences preferences;
  const IkillApp({super.key, required this.content, required this.preferences});
  @override
  State<IkillApp> createState() => _IkillAppState();
}

class _IkillAppState extends State<IkillApp> {
  final navigatorKey=GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    PushService.clicked.addListener(openPush);
    WidgetsBinding.instance.addPostFrameCallback((_)=>openPush());
  }
  void openPush() {
    final context=navigatorKey.currentState?.overlay?.context;
    if(context!=null)NotificationNavigation.handle(context);
  }
  @override
  void dispose(){PushService.clicked.removeListener(openPush);super.dispose();}

  late bool english = widget.preferences.getBool('english') ?? false;
  late bool dark = widget.preferences.getBool('dark') ?? false;

  ThemeData theme(Brightness brightness) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: brand, brightness: brightness),
    scaffoldBackgroundColor: brightness == Brightness.light ? const Color(0xFFF5F8F5) : const Color(0xFF0C1912),
    appBarTheme: const AppBarTheme(centerTitle: false),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    )),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey:navigatorKey,
    title: 'iKILL', debugShowCheckedModeBanner: false,
    theme: theme(Brightness.light), darkTheme: theme(Brightness.dark),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    locale: Locale(english ? 'en' : 'ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: SiteShell(content: widget.content, english: english, dark: dark,
      toggleLanguage: () { setState(() => english = !english); widget.preferences.setBool('english', english); },
      toggleTheme: () { setState(() => dark = !dark); widget.preferences.setBool('dark', dark); }),
  );
}

class SiteShell extends StatefulWidget {
  final SiteContent content;
  final bool english, dark;
  final VoidCallback toggleLanguage, toggleTheme;
  const SiteShell({super.key, required this.content, required this.english,
    required this.dark, required this.toggleLanguage, required this.toggleTheme});
  @override
  State<SiteShell> createState() => _SiteShellState();
}

class _SiteShellState extends State<SiteShell> {
  int selected = 0;
  final scroll = ScrollController();
  final pages = const ['index', 'services', 'sectors', 'locations', 'about', 'contact', 'privacy-policy', 'terms'];
  final keys = const ['nav.home', 'nav.services', 'nav.sectors', 'nav.branches', 'nav.about', 'nav.contact'];
  final icons = const [Icons.home_outlined, Icons.pest_control, Icons.business_outlined,
    Icons.location_on_outlined, Icons.info_outline, Icons.support_agent, Icons.privacy_tip_outlined, Icons.description_outlined];
  String tr(String ar, String en) => widget.english ? en : ar;
  String t(String key, [String fallback = '']) => widget.content.t(key, widget.english, fallback);
  String title(int index) => index < 6 ? t(keys[index]) : index == 6 ? tr('سياسة الخصوصية', 'Privacy policy') : tr('شروط الاستخدام', 'Terms of use');
  void go(int index) {
    setState(() => selected = index);
    if (scroll.hasClients) scroll.jumpTo(0);
  }
  @override
  void dispose() { scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final primary = [0, 1, 3, 5];
    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/images/${widget.dark ? 'ikill-logo-dark.png' : 'ikill-logo-transparent.png'}', height: 40, width: 100, fit: BoxFit.contain),
        actions: [
          TextButton(onPressed: widget.toggleLanguage, child: Text(widget.english ? 'عربي' : 'EN')),
          IconButton(tooltip: tr('المظهر', 'Theme'), onPressed: widget.toggleTheme,
            icon: Icon(widget.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined)),
        ],
      ),
      drawer: Drawer(child: SafeArea(child: ListView(children: [
        const Padding(padding: EdgeInsets.all(24), child: Text('iKILL', style: TextStyle(fontSize: 36, color: brand, fontWeight: FontWeight.w900))),
        for (var i = 0; i < pages.length; i++) ListTile(
          selected: selected == i, leading: Icon(icons[i]), title: Text(title(i)),
          onTap: () { Navigator.pop(context); go(i); },
        ),
        const Divider(),
        ListTile(leading: const Icon(Icons.account_circle_outlined), title: Text(tr('بوابة العميل', 'Client portal')),
          onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ClientPortalPage(english: widget.english))); }),
        ListTile(leading: const Icon(Icons.engineering_outlined), title: Text(tr('مهام الفني', 'Technician tasks')),
          onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute<void>(builder: (_) => TechnicianPage(english: widget.english))); }),
        ListTile(leading: const Icon(Icons.admin_panel_settings_outlined), title: Text(tr('لوحة الإدارة', 'Administration')),
          onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute<void>(builder: (_) => AdminPage(english: widget.english))); }),
      ]))),
      body: SafeArea(child: ListView(controller: scroll, padding: const EdgeInsets.only(bottom: 32), children: [
        if (!Backend.ready) Padding(padding: const EdgeInsets.all(12), child: MaterialBanner(
          content: Text(tr('المحتوى متاح دون اتصال. خدمات الطلبات والإدارة تحتاج إعداد Supabase للتطبيق.',
            'Offline content available. Requests and administration require Supabase configuration.')),
          leading: const Icon(Icons.cloud_off_outlined), actions: [TextButton(onPressed: () => go(5), child: Text(tr('تواصل معنا', 'Contact')))],
        )),
        if (selected == 0) ...home()
        else ...[
          Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 12), child: Text(title(selected), style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800))),
          if (selected == 1) ...services()
          else if (selected == 3) ...[branchCard(), branches()]
          else if (selected == 5) ...[
            Padding(padding: const EdgeInsets.all(20), child: RequestForm(english: widget.english, content: widget.content,
              onPrivacy: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => LegalPage(content: widget.content, english: widget.english))))),
            contactCard(),
          ]
          else ...contentBlocks(pages[selected]),
        ],
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24), child: Wrap(spacing: 12, runSpacing: 12, children: [
          OutlinedButton.icon(onPressed: () => openLink(context, 'tel:01020019042'), icon: const Icon(Icons.phone_outlined), label: Text(t('cta.call', tr('اتصل الآن', 'Call now')))),
          OutlinedButton.icon(onPressed: () => openLink(context, 'https://wa.me/201020019042'), icon: const Icon(Icons.chat_bubble_outline), label: Text(tr('واتساب', 'WhatsApp'))),
        ])),
        Center(child: TextButton(onPressed: () => go(6), child: Text('${tr('سياسة الخصوصية', 'Privacy policy')} · © iKILL'))),
      ])),
      bottomNavigationBar: NavigationBar(
        selectedIndex: primary.contains(selected) ? primary.indexOf(selected) : 0,
        onDestinationSelected: (i) => go(primary[i]),
        destinations: [for (final index in primary) NavigationDestination(icon: Icon(icons[index]), label: title(index))],
      ),
    );
  }

  List<Widget> home() => [
    Container(
      constraints: const BoxConstraints(minHeight: 420),
      decoration: BoxDecoration(image: DecorationImage(image: const AssetImage('assets/images/eco-environment-hero.webp'),
        fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: .58), BlendMode.darken))),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 50), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(24)),
          child: Text(t('hero.badge'), style: const TextStyle(color: Color(0xFFBBF7D0)))),
        const SizedBox(height: 24),
        Text('${t('hero.title1')} ${t('hero.title2')}\n${t('hero.title3')}',
          style: const TextStyle(color: Colors.white, fontSize: 38, height: 1.4, fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        Text(t('hero.subtitle'), style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.8)),
        const SizedBox(height: 24),
        Wrap(spacing: 12, runSpacing: 12, children: [
          FilledButton.icon(onPressed: () => go(5), icon: const Icon(Icons.calendar_month_outlined), label: Text(t('hero.cta1'))),
          OutlinedButton(onPressed: () => go(1), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)), child: Text(t('hero.cta2'))),
        ]),
      ])),
    ),
    FutureBuilder<Map<String, dynamic>>(
      future: Backend.publicSettings(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        return Padding(padding: const EdgeInsets.all(20), child: Wrap(spacing: 12, runSpacing: 12, children: [
          for (var i = 1; i <= 4; i++) SizedBox(width: (MediaQuery.sizeOf(context).width - 52) / 2,
            child: panel(Column(children: [
              Text(i == 1 ? '15' : '${data['stat${i}Value'] ?? t('stat$i.value')}', style: const TextStyle(fontSize: 30, color: brand, fontWeight: FontWeight.w900)),
              Text(widget.english ? t('stat$i.label') : '${data['stat${i}Label'] ?? t('stat$i.label')}', textAlign: TextAlign.center),
            ]))),
        ]));
      },
    ),
    sectionTitle(t('services.title')),
    ...services(preview: true),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: TextButton(onPressed: () => go(1), child: Text(t('services.all')))),
    sectionTitle(t('sectors.title')),
    ...contentBlocks('sectors', compact: true),
    sectionTitle(t('logos.title')),
    FutureBuilder<List<String>>(
      future: _partners(),
      builder: (context, snapshot) => SizedBox(height: 100, child: ListView.separated(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: snapshot.data?.length ?? 0, separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (_, i) => Container(width: 130, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Image.asset(snapshot.data![i], fit: BoxFit.contain)),
      )),
    ),
    ...homeExtra(),
    sectionTitle(t('locations.title')),
    branchCard(),
    Padding(padding: const EdgeInsets.all(20), child: panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t('cta.title'), style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12), Text(t('cta.subtitle')), const SizedBox(height: 18),
      FilledButton(onPressed: () => go(5), child: Text(t('cta.book'))),
    ]))),
  ];

  List<Widget> homeExtra() {
    final blocks = widget.content.pages['index'] as List<dynamic>;
    final extra = [...blocks.skip(9).take(7), ...blocks.skip(20)];
    return [for (final dynamic b in extra)
      Padding(padding: const EdgeInsets.fromLTRB(24, 14, 24, 6), child: Text(
        widget.content.block(Map<String, dynamic>.from(b as Map), widget.english),
        style: b['tag'].toString().startsWith('h')
          ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)
          : const TextStyle(height: 1.8, fontSize: 16),
      ))];
  }

  Future<List<String>> _partners() async {
    final manifest = await AssetManifest.loadFromAssetBundle(DefaultAssetBundle.of(context));
    return manifest.listAssets().where((s) => s.startsWith('assets/images/partners-webp/')).toList();
  }

  Widget sectionTitle(String text) => Padding(padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
    child: Text(text, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)));

  Widget panel(Widget child) => Card(margin: EdgeInsets.zero, elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: brand.withValues(alpha: .15))),
    child: Padding(padding: const EdgeInsets.all(20), child: child));

  List<Widget> services({bool preview = false}) => [
    for (final item in widget.content.services.take(preview ? 3 : 100))
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7), child: panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(14)),
            child: SvgPicture.asset(item['image'], width: 44, height: 44)),
          const SizedBox(width: 16),
          Expanded(child: Text(widget.english ? item['subtitle'] : item['title'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 14),
        Text(widget.content.translate(item['description'], widget.english), style: const TextStyle(height: 1.8)),
        const SizedBox(height: 12),
        TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => Scaffold(
          appBar: AppBar(title: Text(widget.english ? item['subtitle'] : item['title'])),
          body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: RequestForm(english: widget.english, content: widget.content,
            initialMessage: widget.english ? item['subtitle'] : item['title'],
            onPrivacy: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => LegalPage(content: widget.content, english: widget.english))))),
        ))), icon: const Icon(Icons.arrow_forward), label: Text(t('hero.cta1'))),
      ]))),
  ];

  List<Widget> contentBlocks(String page, {bool compact = false}) {
    final blocks = (widget.content.pages[page] as List<dynamic>);
    return [for (final dynamic item in (compact ? blocks.take(8) : blocks))
      Padding(padding: EdgeInsets.fromLTRB(24, item['tag'].toString().startsWith('h') ? 16 : 5, 24, 8),
        child: Text(widget.content.block(Map<String, dynamic>.from(item as Map), widget.english),
          style: item['tag'].toString().startsWith('h')
            ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)
            : const TextStyle(fontSize: 16, height: 1.9))),
    ];
  }

  Widget contactCard() => Padding(padding: const EdgeInsets.all(20), child: panel(Column(children: [
    ListTile(leading: const Icon(Icons.call_outlined), title: const Text('01020019042'), onTap: () => openLink(context, 'tel:01020019042')),
    ListTile(leading: const Icon(Icons.mail_outline), title: const Text('info@ikill.net'), onTap: () => openLink(context, 'mailto:info@ikill.net')),
    ListTile(leading: const Icon(Icons.schedule), title: Text(tr('24 ساعة / 7 أيام', '24 hours / 7 days'))),
  ])));

  Widget branchCard() => Padding(padding: const EdgeInsets.all(20), child: panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Icon(Icons.location_on, size: 36, color: brand), const SizedBox(height: 12),
    Text(t('branch.name', tr('الفرع الرئيسي - الجيزة', 'Head office — Giza')), style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12), Text(tr('مصر · خدمة على مدار الساعة', 'Egypt · Around-the-clock service')),
    const SizedBox(height: 18), Wrap(spacing: 12, runSpacing: 12, children: [
      FilledButton.icon(onPressed: () => openLink(context, 'tel:01020019042'), icon: const Icon(Icons.call), label: const Text('01020019042')),
      OutlinedButton.icon(onPressed: () => openLink(context, 'https://www.google.com/maps/search/?api=1&query=iKILL+Giza+Egypt'), icon: const Icon(Icons.map_outlined), label: Text(tr('الخريطة', 'Map'))),
    ]),
  ])));

  Widget branches() {
    if (!Backend.ready) return const SizedBox.shrink();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Backend.publicBranches(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(24), child: Text(tr('تعذّر تحميل الفروع. حاول لاحقاً.', 'Unable to load branches. Please try later.')));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty) return Padding(padding: const EdgeInsets.all(24), child: Text(t('locations.empty')));
        return Column(children: [for (final doc in snapshot.data!)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: panel(ListTile(
            leading: const Icon(Icons.apartment, color: brand),
            title: Text('${doc[widget.english ? 'nameEn' : 'nameAr'] ?? ''}'),
            subtitle: Text('${doc[widget.english ? 'countryEn' : 'countryAr'] ?? ''}\n${doc['phone'] ?? ''}'),
            onTap: doc['phone'] == null ? null : () => openLink(context, 'tel:${doc['phone']}'),
          ))),
        ]);
      },
    );
  }
}

class LegalPage extends StatelessWidget {
  final SiteContent content;
  final bool english;
  const LegalPage({super.key, required this.content, required this.english});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(english ? 'Privacy policy' : 'سياسة الخصوصية')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      for (final dynamic block in content.pages['privacy-policy'] as List<dynamic>)
        Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(content.block(Map<String, dynamic>.from(block as Map), english), style: TextStyle(
          fontSize: block['tag'].toString().startsWith('h') ? 21 : 16, height: 1.8))),
    ]),
  );
}
