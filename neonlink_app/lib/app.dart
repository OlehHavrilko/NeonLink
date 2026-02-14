import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/neon_theme.dart';
import 'presentation/navigation/app_router.dart';

class NeonLinkApp extends ConsumerWidget {
  const NeonLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    
    return MaterialApp.router(
      title: 'NeonLink',
      debugShowCheckedModeBanner: false,
      theme: NeonTheme.darkTheme,
      routerConfig: router,
    );
  }
}
