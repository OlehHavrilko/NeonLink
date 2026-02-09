import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Global error handling
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // Log to crash reporter
    debugPrint('Flutter Error: ${details.exception}');
  };
  
  runApp(
    ProviderScope(
      child: NeonLinkApp(),
    ),
  );
}
