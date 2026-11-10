import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_tokens.dart';
import 'features/shell/home_shell.dart';
import 'state/providers.dart';

class SubBurnApp extends ConsumerWidget {
  const SubBurnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(settingsProvider).themePreference;

    return MaterialApp(
      title: 'SubBurn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Defaults to system: the app follows the phone until the user chooses.
      themeMode: preference.mode,
      themeAnimationDuration: SbMotion.quick,
      // A light sweep on switch, not a hard cut. Disabled under reduce-motion
      // by MaterialApp itself.
      themeAnimationCurve: Curves.easeInOut,
      home: const HomeShell(),
      builder: (context, child) {
        return ColoredBox(
          color: context.sb.bg,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
