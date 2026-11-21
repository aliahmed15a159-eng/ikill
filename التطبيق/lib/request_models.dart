import 'dart:math';

const propertyOptions = {
  'apartment': ['شقة', 'Apartment'],
  'villa': ['فيلا', 'Villa'],
  'house': ['بيت', 'House'],
};
const problemOptions = {
  'cockroaches': ['صراصير', 'Cockroaches'],
  'rodents': ['قوارض', 'Rodents'],
  'bed_bugs': ['بق فراش', 'Bed bugs'],
  'general_pests': ['آفات عامة', 'General pests'],
};
const sectorOptions = {
  'factory': ['مصنع', 'Factory'],
  'restaurant': ['مطعم', 'Restaurant'],
  'commercial': ['منشأة تجارية', 'Commercial facility'],
  'industrial': ['منشأة صناعية', 'Industrial facility'],
  'other': ['قطاع آخر', 'Other sector'],
};
String optionLabel(Map<String, List<String>> options, String key, bool english) =>
    options[key]?[english ? 1 : 0] ?? key;

String newRequestId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String normalizeDigits(String value) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  var result = value.trim().replaceAll('٫', '.');
  for (var i = 0; i < 10; i++) {
    result = result.replaceAll(arabic[i], '$i');
  }
  return result;
}

String? validPriceInput(String value) {
  final text = normalizeDigits(value);
  if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(text)) return null;
  final amount = num.tryParse(text);
  return amount != null && amount > 0 && amount <= 9999999999.99 ? amount.toStringAsFixed(2) : null;
}

class ResidentialQuote {
  final String id, amount, currency;
  const ResidentialQuote({required this.id, required this.amount, required this.currency});
  factory ResidentialQuote.fromJson(Map<String, dynamic> row) => ResidentialQuote(
    id: row['price_id'] as String,
    amount: (row['amount'] as num).toStringAsFixed(2),
    currency: row['currency'] as String,
  );
}
