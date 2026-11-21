import 'package:flutter_test/flutter_test.dart';
import 'package:ikill_native/request_models.dart';

void main() {
  test('Twelve supported price combinations and Arabic money validation', () {
    expect(propertyOptions.length * problemOptions.length, 12);
    expect(validPriceInput('٢٥٠٫٥٠'), '250.50');
    for (final invalid in ['0', '-1', 'NaN', '12.345', '10000000000', '']) {
      expect(validPriceInput(invalid), isNull);
    }
  });
  test('Request identifiers are unique UUID v4', () {
    final ids = List.generate(100, (_) => newRequestId());
    expect(ids.toSet().length, 100);
    expect(ids.every((id) => RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(id)), isTrue);
  });
}
