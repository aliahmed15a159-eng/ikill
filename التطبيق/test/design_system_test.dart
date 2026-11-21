import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikill_native/design/app_theme.dart';
import 'package:ikill_native/design/brand_controller.dart';
import 'package:ikill_native/design/components.dart';

void main(){
  test('Primary foreground maintains AA for arbitrary white-label colours',(){
    for(final color in [Colors.white,Colors.black,Colors.yellow,Colors.green,const Color(0xff15803d),const Color(0xff0a4d3c)]){
      for(final brightness in Brightness.values){
        final theme=AppTheme.build(primary:color,brightness:brightness);
        expect(theme.colorScheme.primary,color);
        expect(AppTheme.contrast(color,theme.colorScheme.onPrimary),greaterThanOrEqualTo(4.5));
        expect(AppTheme.contrast(theme.colorScheme.surface,theme.colorScheme.onSurface),greaterThanOrEqualTo(7));
        expect(theme.textTheme.bodyMedium?.fontFamily,'Cairo');
        expect(theme.extensions.values.whereType<AppPalette>(),isNotEmpty);
      }
    }
    expect(BrandController.parseColor('#bad'),isNull);
    expect(BrandController.parseColor('0A4D3C'),const Color(0xff0a4d3c));
  });
  testWidgets('Reusable controls handle busy, RTL and large text on a small phone',(tester)async{
    tester.view.physicalSize=const Size(360,800);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    var presses=0;
    final input=TextEditingController();addTearDown(input.dispose);
    await tester.pumpWidget(MaterialApp(theme:AppTheme.build(primary:AppTheme.forest,brightness:Brightness.light),home:Directionality(textDirection:TextDirection.rtl,child:MediaQuery(data:const MediaQueryData(textScaler:TextScaler.linear(1.6)),child:Scaffold(body:ListView(padding:const EdgeInsets.all(20),children:[AppInput(controller:input,label:'رقم التواصل',icon:Icons.phone),AppCard(child:StatusBadge(label:'قيد التنفيذ',tone:StatusTone.info)),LoadingButton(label:'حفظ التغييرات',busy:true,onPressed:()=>presses++),const SkeletonLoader(count:1)]))))));
    await tester.pump();
    await tester.tap(find.text('حفظ التغييرات'));expect(presses,0);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Semantic snackbars use central floating treatment',(tester)async{
    await tester.pumpWidget(MaterialApp(theme:AppTheme.build(primary:AppTheme.forest,brightness:Brightness.dark),home:Scaffold(body:Builder(builder:(context)=>TextButton(onPressed:()=>AppToast.show(context,'تم الحفظ'),child:const Text('Save'))))));
    await tester.tap(find.text('Save'));await tester.pump();expect(find.text('تم الحفظ'),findsOneWidget);expect(tester.takeException(),isNull);
  });
}
