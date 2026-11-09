import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_tokens.dart';
import 'features/shell/home_shell.dart';

class SubBurnApp extends ConsumerWidget {
  const SubBurnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'SubBurn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      themeAnimationDuration: SbMotion.quick,
      home: const HomeShell(),
      builder: (context, child) {
        // Dark only, and never let a device's light mode invert a surface.
        return ColoredBox(
          color: SbColors.bg,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
