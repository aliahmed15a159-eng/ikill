import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend.dart';
import '../config/brand_config.dart';
import '../supabase_client.dart';

/// Presentation only. This cache never grants tenant membership or permissions.
class BrandController extends ChangeNotifier {
  static final instance = BrandController();
  String name = BrandConfig.current.companyName;
  Color primary = BrandConfig.current.primaryColor;
  String? logoUrl;
  bool _loading = false;
  String get _key => 'mobile-brand-v1:${SupabaseConnection.url}:${SupabaseConnection.brandSlug}';

  static Color? parseColor(Object? value) {
    if (value is! String || !RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) return null;
    return Color(int.parse('ff$value', radix:16));
  }
  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    name = preferences.getString('$_key:name') ?? name;
    primary = parseColor(preferences.getString('$_key:primary')) ?? primary;
    notifyListeners();
    unawaited(refresh());
  }
  Future<void> refresh() async {
    if (_loading || !Backend.ready) return;
    _loading = true;
    try {
      final raw = await supabaseClient.rpc('get_auth_brand', params:{'brand_slug':SupabaseConnection.brandSlug}).timeout(const Duration(seconds:10));
      if (raw is! Map) return;
      final color = parseColor(raw['primary_hex']);
      final company = raw['company_name'];
      if (color == null || company is! String || company.trim().isEmpty) return;
      String? url;
      final path = raw['logo_path'];
      if (path is String && path.isNotEmpty) {
        try { url = await supabaseClient.storage.from('brand-assets').createSignedUrl(path,3600).timeout(const Duration(seconds:10)); } catch (_) { /* Local logo is always available. */ }
      }
      name = company; primary = color; logoUrl = url;
      notifyListeners();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('$_key:name',company);
      await preferences.setString('$_key:primary',raw['primary_hex'] as String);
    } catch (_) { /* Offline: keep the last validated identity, never blank the UI. */ }
    finally { _loading = false; }
  }
}

class BrandLogo extends StatelessWidget {
  final double height;
  const BrandLogo({super.key,this.height=40});
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable:BrandController.instance,builder:(context,child) {
    final brand = BrandController.instance;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final local = Image.asset(dark ? BrandConfig.current.darkLogoAsset : BrandConfig.current.logoAsset,height:height,fit:BoxFit.contain,semanticLabel:brand.name);
    return Semantics(label:brand.name,image:true,child:ConstrainedBox(constraints:BoxConstraints(maxWidth:180,maxHeight:height),child:brand.logoUrl==null?local:Image.network(brand.logoUrl!,height:height,fit:BoxFit.contain,errorBuilder:(_,error,stack)=>local)));
  });
}
