import 'dart:async';
import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Explicit busy state prevents duplicate commands without changing backend logic.
class LoadingButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  const LoadingButton({super.key,required this.label,required this.onPressed,this.busy=false,this.icon});
  @override
  Widget build(BuildContext context)=>Semantics(button:true,liveRegion:busy,child:FilledButton(onPressed:busy?null:onPressed,child:AnimatedSize(duration:AppSpace.duration,child:Row(mainAxisSize:MainAxisSize.min,mainAxisAlignment:MainAxisAlignment.center,children:[if(busy)...[SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Theme.of(context).colorScheme.onSurfaceVariant)),const SizedBox(width:10)]else if(icon!=null)...[Icon(icon),const SizedBox(width:10)],Flexible(child:Text(label,textAlign:TextAlign.center))]))));
}
class AppInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final IconData? icon;
  final bool enabled;
  final Iterable<String>? autofillHints;
  const AppInput({super.key,required this.controller,required this.label,this.hint,this.validator,this.keyboardType,this.icon,this.enabled=true,this.autofillHints});
  @override
  Widget build(BuildContext context)=>TextFormField(controller:controller,enabled:enabled,keyboardType:keyboardType,autofillHints:autofillHints,textInputAction:TextInputAction.next,autovalidateMode:AutovalidateMode.onUserInteraction,validator:validator,decoration:InputDecoration(labelText:label,hintText:hint,prefixIcon:icon==null?null:Icon(icon)));
}
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AppCard({super.key,required this.child,this.padding=const EdgeInsets.all(20)});
  @override
  Widget build(BuildContext context)=>Card(child:Padding(padding:padding,child:child));
}

enum StatusTone { neutral,success,warning,error,info }
class StatusBadge extends StatelessWidget {
  final String label;
  final StatusTone tone;
  const StatusBadge({super.key,required this.label,this.tone=StatusTone.neutral});
  static StatusTone forStatus(String status)=>switch(status){
    'paid'||'completed'||'ready'||'approved'||'active'=>StatusTone.success,
    'pending'||'survey_pending'||'pending_review'||'partial'||'unpaid'=>StatusTone.warning,
    'rejected'||'cancelled'||'failed'||'overdue'=>StatusTone.error,
    'in_progress'||'scheduled'||'processing'=>StatusTone.info,
    _=>StatusTone.neutral,
  };
  @override
  Widget build(BuildContext context){final s=Theme.of(context).colorScheme,p=Theme.of(context).extension<AppPalette>();final c=switch(tone){StatusTone.success=>p?.success??s.primary,StatusTone.warning=>p?.warning??s.secondary,StatusTone.error=>s.error,StatusTone.info=>p?.info??s.secondary,StatusTone.neutral=>s.onSurfaceVariant};return Semantics(label:label,child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),decoration:BoxDecoration(color:c.withValues(alpha:.10),borderRadius:BorderRadius.circular(12),border:Border.all(color:c.withValues(alpha:.18))),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(switch(tone){StatusTone.success=>Icons.check_circle_outline,StatusTone.warning=>Icons.schedule,StatusTone.error=>Icons.error_outline,StatusTone.info=>Icons.info_outline,StatusTone.neutral=>Icons.circle_outlined},size:16,color:c),const SizedBox(width:6),Flexible(child:Text(label,style:Theme.of(context).textTheme.labelMedium?.copyWith(color:c,fontWeight:FontWeight.w700)))])));}
}
abstract final class AppToast {
  static void show(BuildContext context,String message,{bool error=false}){
    final messenger=ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content:Row(children:[Icon(error?Icons.error_outline:Icons.check_circle_outline,color:Theme.of(context).brightness==Brightness.dark?AppTheme.ink:Colors.white),const SizedBox(width:12),Expanded(child:Text(message))])));
  }
}

/// No shimmer flashes or looping animation: accessible, cheap and reduced-motion safe.
class SkeletonLoader extends StatelessWidget {
  final int count;
  const SkeletonLoader({super.key,this.count=3});
  @override
  Widget build(BuildContext context)=>Semantics(label:Localizations.localeOf(context).languageCode=='ar'?'جارٍ التحميل':'Loading',liveRegion:true,child:ExcludeSemantics(child:SingleChildScrollView(physics:const NeverScrollableScrollPhysics(),padding:const EdgeInsets.all(20),child:Column(children:List.generate(count,(_)=>AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[_bar(context,.6,18),const SizedBox(height:16),_bar(context,1,12),const SizedBox(height:10),_bar(context,.8,12),const SizedBox(height:20),_bar(context,.35,36)])))))));
  Widget _bar(BuildContext context,double width,double height)=>FractionallySizedBox(widthFactor:width,child:Container(height:height,decoration:BoxDecoration(color:Theme.of(context).colorScheme.onSurface.withValues(alpha:.07),borderRadius:BorderRadius.circular(8))));
}

/// In-place page fade; honours system reduced motion and does not build two forms.
class PageEntrance extends StatefulWidget {
  final Widget child;
  const PageEntrance({super.key,required this.child});
  @override
  State<PageEntrance> createState()=>_PageEntranceState();
}
class _PageEntranceState extends State<PageEntrance> with SingleTickerProviderStateMixin {
  late final controller=AnimationController(vsync:this,duration:AppSpace.duration);
  @override
  void didChangeDependencies(){super.didChangeDependencies();if(MediaQuery.disableAnimationsOf(context)){controller.value=1;}else{unawaited(controller.forward());}}
  @override
  void dispose(){controller.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>FadeTransition(opacity:CurvedAnimation(parent:controller,curve:Curves.easeOut),child:widget.child);
}
