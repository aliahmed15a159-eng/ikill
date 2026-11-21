import 'package:flutter/material.dart';

abstract final class AppSpace {
  static const double xs=4, sm=8, md=12, lg=16, xl=24, xxl=32;
  static const page=EdgeInsets.all(xl);
  static const duration=Duration(milliseconds:250);
}

/// Semantic colours are independent of workflow status and never encode authority.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color success, warning, info, accent;
  const AppPalette({required this.success,required this.warning,required this.info,required this.accent});
  static AppPalette of(BuildContext context)=>Theme.of(context).extension<AppPalette>()!;
  @override
  AppPalette copyWith({Color? success,Color? warning,Color? info,Color? accent})=>AppPalette(success:success??this.success,warning:warning??this.warning,info:info??this.info,accent:accent??this.accent);
  @override
  AppPalette lerp(covariant AppPalette? other,double t)=>other==null?this:AppPalette(success:Color.lerp(success,other.success,t)!,warning:Color.lerp(warning,other.warning,t)!,info:Color.lerp(info,other.info,t)!,accent:Color.lerp(accent,other.accent,t)!);
}

abstract final class AppTheme {
  static const forest=Color(0xff075a3c), ink=Color(0xff123427);
  static double contrast(Color a,Color b){final x=a.computeLuminance(),y=b.computeLuminance();return (x>y?x+.05:y+.05)/(x>y?y+.05:x+.05);}
  static Color onColor(Color color)=>contrast(color,Colors.white)>=contrast(color,Colors.black)?Colors.white:Colors.black;
  static Color whiteReadable(Color color){var result=color;while(contrast(result,Colors.white)<4.5){result=Color.lerp(result,Colors.black,.12)!;}return result;}
  static LinearGradient hero(BuildContext context){final s=Theme.of(context).colorScheme;return LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color.lerp(s.primary,Colors.black,.68)!,whiteReadable(Color.lerp(s.primary,Colors.black,.22)!)]);}

  static ThemeData build({required Color primary,required Brightness brightness,bool english=false}) {
    final dark=brightness==Brightness.dark;
    final base=ColorScheme.fromSeed(seedColor:primary,brightness:brightness);
    final scheme=base.copyWith(
      // Keep exact brand colour for identity; guarantee readable foreground.
      primary:primary,onPrimary:onColor(primary),
      secondary:HSLColor.fromColor(primary).withLightness(dark?.72:.23).toColor(),
      surface:dark?const Color(0xff102f20):Colors.white,
      onSurface:dark?const Color(0xffeffcf0):ink,
      onSurfaceVariant:dark?const Color(0xffb8d7bf):const Color(0xff466557),
      outline:dark?const Color(0xff779385):const Color(0xff6b8275),
      outlineVariant:dark?const Color(0xff294334):const Color(0xffdceee2),
      error:dark?const Color(0xffffb4ab):const Color(0xffb3261e),
    );
    final theme=ThemeData(useMaterial3:true,colorScheme:scheme,brightness:brightness,fontFamily:english?'Inter':'Cairo',fontFamilyFallback:const ['Cairo','Inter']);
    final text=theme.textTheme.copyWith(
      displaySmall:TextStyle(fontSize:34,height:1.35,fontWeight:FontWeight.w800,color:scheme.onSurface),
      headlineLarge:TextStyle(fontSize:30,height:1.4,fontWeight:FontWeight.w800,color:scheme.onSurface),
      headlineMedium:TextStyle(fontSize:26,height:1.4,fontWeight:FontWeight.w800,color:scheme.onSurface),
      headlineSmall:TextStyle(fontSize:23,height:1.45,fontWeight:FontWeight.w700,color:scheme.onSurface),
      titleLarge:TextStyle(fontSize:20,height:1.5,fontWeight:FontWeight.w700,color:scheme.onSurface),
      titleMedium:TextStyle(fontSize:16,height:1.5,fontWeight:FontWeight.w700,color:scheme.onSurface),
      bodyLarge:TextStyle(fontSize:16,height:1.7,color:scheme.onSurface),
      bodyMedium:TextStyle(fontSize:14,height:1.65,color:scheme.onSurface),
      bodySmall:TextStyle(fontSize:12,height:1.6,color:scheme.onSurfaceVariant),
      labelLarge:const TextStyle(fontSize:14,height:1.4,fontWeight:FontWeight.w700),
    ).apply(fontFamily:english?'Inter':'Cairo');
    final shape=RoundedRectangleBorder(borderRadius:BorderRadius.circular(20));
    return theme.copyWith(
      textTheme:text,scaffoldBackgroundColor:dark?const Color(0xff081c13):const Color(0xfff5faf5),
      extensions:[AppPalette(success:dark?const Color(0xff81d79b):const Color(0xff18663c),warning:dark?const Color(0xffffd180):const Color(0xff875500),info:dark?const Color(0xff99caff):const Color(0xff195f99),accent:HSLColor.fromColor(primary).withHue((HSLColor.fromColor(primary).hue+287)%360).withSaturation(.86).withLightness(.69).toColor())],
      visualDensity:VisualDensity.standard,materialTapTargetSize:MaterialTapTargetSize.padded,
      appBarTheme:AppBarTheme(backgroundColor:scheme.surface,foregroundColor:scheme.onSurface,elevation:0,scrolledUnderElevation:1,centerTitle:false,titleTextStyle:text.titleLarge,toolbarHeight:68,surfaceTintColor:Colors.transparent),
      cardTheme:CardTheme(color:scheme.surface,surfaceTintColor:Colors.transparent,elevation:1,shadowColor:primary.withValues(alpha:.12),margin:const EdgeInsets.symmetric(vertical:8),shape:shape.copyWith(side:BorderSide(color:scheme.outlineVariant.withValues(alpha:.7)))),
      inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:dark?const Color(0xff16271e):Colors.white,contentPadding:const EdgeInsets.symmetric(horizontal:18,vertical:18),errorMaxLines:3,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide(color:scheme.outlineVariant)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide(color:scheme.outlineVariant)),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide(color:scheme.primary,width:2)),labelStyle:text.bodyMedium?.copyWith(color:scheme.onSurfaceVariant)),
      filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(minimumSize:const Size(48,54),padding:const EdgeInsets.symmetric(horizontal:24,vertical:16),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),textStyle:text.labelLarge)),
      outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(minimumSize:const Size(48,52),foregroundColor:dark?base.primary:scheme.secondary,padding:const EdgeInsets.symmetric(horizontal:20,vertical:14),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),side:BorderSide(color:scheme.outlineVariant))),
      textButtonTheme:TextButtonThemeData(style:TextButton.styleFrom(minimumSize:const Size(48,48),foregroundColor:dark?base.primary:scheme.secondary)),
      iconButtonTheme:IconButtonThemeData(style:IconButton.styleFrom(minimumSize:const Size(48,48))),
      navigationBarTheme:NavigationBarThemeData(height:76,backgroundColor:scheme.surface,indicatorColor:base.primaryContainer,elevation:0,labelTextStyle:WidgetStatePropertyAll(text.labelMedium?.copyWith(fontWeight:FontWeight.w700)),iconTheme:WidgetStateProperty.resolveWith((s)=>IconThemeData(color:s.contains(WidgetState.selected)?base.onPrimaryContainer:scheme.onSurfaceVariant))),
      snackBarTheme:SnackBarThemeData(behavior:SnackBarBehavior.floating,backgroundColor:dark?const Color(0xffd4f5d6):ink,contentTextStyle:text.bodyMedium?.copyWith(color:dark?ink:Colors.white),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),insetPadding:const EdgeInsets.all(16)),
      bottomSheetTheme:BottomSheetThemeData(backgroundColor:scheme.surface,showDragHandle:true,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(28)))),
      dialogTheme:DialogTheme(backgroundColor:scheme.surface,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(28))),
      dividerTheme:DividerThemeData(color:scheme.outlineVariant,space:24,thickness:1),
      chipTheme:theme.chipTheme.copyWith(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),side:BorderSide.none,padding:const EdgeInsets.symmetric(horizontal:8,vertical:6)),
      listTileTheme:ListTileThemeData(contentPadding:const EdgeInsets.symmetric(horizontal:20,vertical:8),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),minVerticalPadding:12,iconColor:scheme.secondary),
      pageTransitionsTheme:const PageTransitionsTheme(builders:{TargetPlatform.android:FadeUpwardsPageTransitionsBuilder(),TargetPlatform.iOS:CupertinoPageTransitionsBuilder()}),
    );
  }
}
