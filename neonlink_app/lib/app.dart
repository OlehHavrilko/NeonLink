import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/neon_theme.dart';
import 'presentation/navigation/app_router.dart';

class NeonLinkApp extends ConsumerWidget {
  const NeonLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    
    return MaterialApp.router(
      title: 'NeonLink',
      debugShowCheckedModeBanner: false,
      theme: NeonTheme.lightTheme,
      darkTheme: NeonTheme.darkTheme,
      themeMode: themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ru'),
        Locale('zh'),
        Locale('de'),
        Locale('es'),
      ],
      routerConfig: appRouter,
    );
  }
}

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.dark;
});
