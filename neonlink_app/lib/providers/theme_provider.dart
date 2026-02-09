import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/neon_theme.dart';

class ThemeNotifier extends Notifier<NeonTheme> {
  @override
  NeonTheme build() => const NeonTheme();

  void setTheme(NeonTheme theme) {
    state = theme;
  }

  void toggleOLEDMode() {
    state = state.copyWith(isOLEDMode: !state.isOLEDMode);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, NeonTheme>(
  ThemeNotifier.new,
);
