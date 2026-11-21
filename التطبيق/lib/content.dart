import 'dart:convert';
import 'package:flutter/services.dart';

class SiteContent {
  final Map<String, dynamic> translations;
  final Map<String, dynamic> pages;
  final List<dynamic> services;
  const SiteContent(this.translations, this.pages, this.services);

  static Future<SiteContent> load() async {
    final files = await Future.wait([
      rootBundle.loadString('assets/data/translations.json'),
      rootBundle.loadString('assets/data/pages.json'),
      rootBundle.loadString('assets/data/services.json'),
    ]);
    return SiteContent(jsonDecode(files[0]) as Map<String, dynamic>,
      jsonDecode(files[1]) as Map<String, dynamic>, jsonDecode(files[2]) as List<dynamic>);
  }

  String t(String key, bool english, [String fallback = '']) {
    final values = translations['translations'][english ? 'en' : 'ar'] as Map<String, dynamic>;
    return values[key]?.toString() ?? (fallback.isEmpty ? key : fallback);
  }

  String translate(String text, bool english) => english
      ? (translations['static'][text]?.toString() ?? text) : text;

  String block(Map<String, dynamic> b, bool english) {
    if ((b['key'] as String).isNotEmpty) return t(b['key'], english, b['text']);
    var text = b['text'] as String;
    if (english) {
      for (final part in b['parts'] as List<dynamic>) {
        text = text.replaceAll(part['text'] as String, t(part['key'], true, part['text']));
      }
    }
    return translate(text, english);
  }
}
