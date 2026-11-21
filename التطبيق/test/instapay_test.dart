import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikill_native/instapay_service.dart';

void main() {
  test('QR uploads restrict type and size before upload', () {
    expect(InstapayService.imageType(Uint8List.fromList([137,80,78,71,13,10,26,10])), 'image/png');
    expect(InstapayService.imageType(Uint8List.fromList([255,216,255,0,0,0,0,0])), 'image/jpeg');
    expect(InstapayService.imageType(Uint8List(0)), isNull);
    expect(InstapayService.imageType(Uint8List.fromList([60,115,118,103,62,0,0,0])), isNull);
    expect(InstapayService.imageType(Uint8List(5*1024*1024+1)), isNull);
  });
}
