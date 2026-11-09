import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_tokens.dart';
import '../dashboard/burn_dashboard_screen.dart';
import '../controls/controls_screen.dart';
import '../quick_add/quick_add_sheet.dart';
import '../renewals/renewals_screen.dart';
import '../studio/viral_receipt_screen.dart';
import '../../services/catalogue_service.dart';
import '../../state/providers.dart';

/// Two real destinations and one action. No placeholder tabs: anything in the
/// navigation bar does something a user can complete.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(catalogueProvider);
    final source = snapshot.value?.source;

    return Scaffold(
      backgroundColor: SbColors.bg,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                BurnDashboardScreen(
                  onAddSubscription: () => QuickAddSheet.show(context),
                ),
                ViralReceiptScreen(
                  onAddSubscription: () => QuickAddSheet.show(context),
                ),
                const RenewalsScreen(),
                const ControlsScreen(),
              ],
            ),
          ),
          if (source == CatalogueSource.bundled && snapshot.hasValue)
            const _OfflineStrip(),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        index: _index,
        onSelect: (i) => setState(() => _index = i),
        onAdd: () => QuickAddSheet.show(context),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.onSelect,
    required this.onAdd,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SbColors.bg,
        border: Border(top: BorderSide(color: SbColors.border)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                icon: Icons.local_fire_department_rounded,
                label: 'Burn',
                selected: index == 0,
                onTap: () => onSelect(0),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.grid_view_rounded,
                label: 'Receipts',
                selected: index == 1,
                onTap: () => onSelect(1),
              ),
            ),
            SizedBox(
              width: 84,
              child: Center(
                child: Semantics(
                  button: true,
                  label: 'Add subscription',
                  child: InkWell(
                    onTap: onAdd,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SbGradients.burn,
                        boxShadow: [SbShadow.ctaGlow],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 24,
                        color: Color(0xFF1A0800),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.notifications_none_rounded,
                label: 'Renewals',
                selected: index == 2,
                onTap: () => onSelect(2),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.tune_rounded,
                label: 'Controls',
                selected: index == 3,
                onTap: () => onSelect(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? SbColors.accent : SbColors.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: SbType.micro.copyWith(
                fontSize: 7.5,
                color: color,
                letterSpacing: 0.06,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineStrip extends StatelessWidget {
  const _OfflineStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      color: SbColors.surfaceHi,
      alignment: Alignment.center,
      child: Text(
        'Offline · using bundled presets',
        style: SbType.micro.copyWith(
          fontSize: 7.5,
          color: SbColors.textMuted,
          letterSpacing: 0.04,
        ),
      ),
    );
  }
}
