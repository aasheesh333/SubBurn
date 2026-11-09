import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/billing_cycle.dart';
import '../../data/models/currency.dart';
import '../../data/models/preset_tool.dart';
import '../../data/models/subscription.dart';
import '../../data/models/usage_guilt.dart';
import '../../data/repositories/subscription_repository.dart';
import '../../services/catalogue_service.dart';
import '../../state/providers.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/segment_pills.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/tool_tile.dart';

/// Screen 2 — Quick Add.
///
/// One sheet, one job: get a real subscription into the ledger in under ten
/// seconds. The preset catalogue is local, so search is instant and works on a
/// plane.
class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key, this.initialPreset});

  final PresetTool? initialPreset;

  static Future<void> show(BuildContext context, {PresetTool? initialPreset}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickAddSheet(initialPreset: initialPreset),
    );
  }

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _queryController = TextEditingController();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController(text: '0');
  final _searchFocus = FocusNode();

  PresetTool? _preset;
  BillingCycle _cycle = BillingCycle.monthly;
  CurrencyCode _currency = CurrencyCode.inr;
  UsageGuilt _guilt = UsageGuilt.dailyDriver;
  String _query = '';
  bool _saving = false;

  /// True while the price in the field is `12 × monthly × 0.83` rather than a
  /// number the user typed. Makes the Yearly toggle reversible: switching back
  /// to monthly divides by the same factor instead of compounding the discount.
  bool _yearlyDiscountApplied = false;

  @override
  void initState() {
    super.initState();
    final preset = widget.initialPreset;
    if (preset != null) {
      _applyPreset(preset);
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _applyPreset(PresetTool preset) {
    setState(() {
      _preset = preset;
      _nameController.text = preset.name;
      _cycle = preset.cycle;
      _currency = preset.currency;
      _priceController.text = formatPlainAmount(preset.defaultPrice);
      _guilt = (preset.category == 'streaming' ||
              preset.category == 'social' ||
              preset.category == 'reading')
          ? UsageGuilt.barelyTouch
          : UsageGuilt.dailyDriver;
    });
  }

  void _clearPreset() {
    setState(() {
      _preset = null;
      _nameController.clear();
      _priceController.text = '0';
      _guilt = UsageGuilt.dailyDriver;
    });
  }

  /// Switching cycle converts the amount instead of relabelling it.
  ///
  /// Monthly -> Yearly applies the advertised 17 % annual discount exactly
  /// once; Yearly -> Monthly removes it and nothing else. Without this the
  /// "-17 %" chip was decoration and the receipt was the only place the
  /// discount existed.
  void _switchCycle(BillingCycle next) {
    if (next == _cycle) return;
    final current = parseAmount(_priceController.text) ?? 0;
    double converted;

    if (next == BillingCycle.yearly && _cycle == BillingCycle.monthly) {
      converted = current * 12 * (1 - annualDiscount);
      _yearlyDiscountApplied = true;
    } else if (next == BillingCycle.monthly && _cycle == BillingCycle.yearly) {
      converted = current / 12 / (_yearlyDiscountApplied ? (1 - annualDiscount) : 1);
      _yearlyDiscountApplied = false;
    } else {
      final monthly = current * _cycle.monthlyFactor;
      converted = monthly / next.monthlyFactor;
      _yearlyDiscountApplied = false;
    }

    setState(() {
      _cycle = next;
      _priceController.text = formatPlainAmount(converted.roundToDouble());
    });
  }

  static const annualDiscount = 0.17;

  void _switchCurrency(CurrencyCode next, double inrPerUsd) {
    if (next == _currency) return;
    final current = parseAmount(_priceController.text) ?? 0;
    final converted = next == CurrencyCode.usd
        ? current / inrPerUsd
        : current * inrPerUsd;
    setState(() {
      _currency = next;
      _priceController.text = next == CurrencyCode.usd
          ? converted.toStringAsFixed(converted >= 100 ? 0 : 2)
          : formatPlainAmount(converted.roundToDouble());
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final price = parseAmount(_priceController.text) ?? 0;
    if (name.isEmpty || price <= 0 || _saving) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              name.isEmpty
                  ? 'Give the subscription a name first.'
                  : 'Enter what it actually costs.',
            ),
          ),
        );
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final preset = _preset;
    final subscription = Subscription(
      id: SubscriptionRepository.newId(),
      name: name,
      vendor: preset?.vendor ?? 'CUSTOM',
      monogram: preset?.monogram ??
          name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((w) => w.isEmpty ? '' : w[0])
              .join()
              .toUpperCase(),
      brandColor: preset?.brandColor ?? 0xFF9A9AA4,
      amount: price,
      currency: _currency,
      cycle: _cycle,
      guilt: _guilt,
      category: preset?.category ?? 'other',
      startDate: now,
      nextBillingDate: _cycle.advance(now),
      cancelUrl: preset?.cancelUrl ?? '',
      presetId: preset?.id,
    );

    await ref
        .read(subscriptionsProvider.notifier)
        .add(subscription, fromPreset: preset != null);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(catalogueProvider);
    final rates = ref.watch(ratesProvider);
    final catalogue = snapshot.value?.catalogue;
    final all = catalogue?.search(_query) ?? const <PresetTool>[];
    // The sheet shows a 3-row preview by default; search reveals more. A
    // 124-tile wall pushes the form off-screen and reads as a directory.
    final results = _query.isEmpty
        ? all.take(12).toList(growable: false)
        : all.take(24).toList(growable: false);
    final hidden = all.length - results.length;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: SbColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SbRadius.sheet),
          ),
          border: Border(top: BorderSide(color: SbColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: SbSpace.x2),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: SbColors.borderHi,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SbSpace.page,
                SbSpace.x3,
                SbSpace.page,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add subscription',
                          style: SbType.h2.copyWith(color: SbColors.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pick a tool, set the burn, log the guilt.',
                          style: SbType.body.copyWith(
                            color: SbColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Close',
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: SbColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  SbSpace.page,
                  SbSpace.x3,
                  SbSpace.page,
                  SbSpace.x4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SearchField(
                      controller: _queryController,
                      focusNode: _searchFocus,
                      toolCount: catalogue?.tools.length ?? 0,
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: SbSpace.x3),
                    Row(
                      children: [
                        Text(
                          _query.isEmpty
                              ? 'POPULAR · ${catalogue?.tools.length ?? 0} TOOLS'
                              : '${results.length} MATCHES',
                          style: SbType.label.copyWith(
                            color: SbColors.textMuted,
                            fontSize: 9,
                          ),
                        ),
                        const Spacer(),
                        if (snapshot.isLoading)
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        else if (snapshot.value != null)
                          StatusBadge(
                            switch (snapshot.value!.source) {
                              CatalogueSource.cdn => 'LIVE',
                              CatalogueSource.cache => 'CACHED',
                              CatalogueSource.bundled => 'BUNDLED',
                            },
                            tone: BadgeTone.neutral,
                          ),
                      ],
                    ),
                    const SizedBox(height: SbSpace.x2),
                    _ToolGrid(
                      tools: results,
                      selectedId: _preset?.id,
                      onSelected: _applyPreset,
                      onClear: _clearPreset,
                    ),
                    if (hidden > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: SbSpace.x2),
                        child: Text(
                          '${_query.isEmpty ? 'Search' : 'Keep typing'} to find '
                          '$hidden more tools.',
                          style: SbType.micro.copyWith(
                            fontSize: 8,
                            color: SbColors.textMuted,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    const SizedBox(height: SbSpace.x4),
                    _Field(
                      label: 'Name',
                      child: TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: SbType.body.copyWith(
                          fontSize: 13,
                          color: SbColors.text,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'e.g. ChatGPT Plus',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: SbSpace.x3),
                    _Field(
                      label: 'Billing cycle',
                      child: SegmentPills<BillingCycle>(
                        values: BillingCycle.values,
                        selected: _cycle,
                        labelOf: (c) => c.label,
                        trailingOf: (c) => c == BillingCycle.yearly ? '−17%' : null,
                        onChanged: _switchCycle,
                      ),
                    ),
                    const SizedBox(height: SbSpace.x3),
                    _Field(
                      label: 'Price per ${_periodNoun(_cycle)}',
                      child: Row(
                        children: [
                          _CurrencyToggle(
                            value: _currency,
                            onChanged: (next) =>
                                _switchCurrency(next, rates.inrPerUsd),
                          ),
                          const SizedBox(width: SbSpace.x2),
                          Expanded(
                            child: TextField(
                              controller: _priceController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'),
                                ),
                              ],
                              style: SbType.moneyLg.copyWith(
                                fontSize: 22,
                                color: SbColors.text,
                              ),
                              decoration: const InputDecoration(
                                hintText: '0',
                              ),
                              onChanged: (_) => setState(
                                () => _yearlyDiscountApplied = false,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: SbSpace.x3),
                    _Field(
                      label: 'Usage guilt level',
                      child: SegmentPills<UsageGuilt>(
                        values: UsageGuilt.values,
                        selected: _guilt,
                        labelOf: (g) => g.label,
                        onChanged: (g) => setState(() => _guilt = g),
                      ),
                    ),
                    const SizedBox(height: SbSpace.x2),
                    Text(
                      _guilt.isGhost
                          ? 'This one will be counted as ghost spend on your receipt.'
                          : 'Counted as active use. Ghost spend stays honest.',
                      style: SbType.caption.copyWith(color: SbColors.textMuted),
                    ),
                    const SizedBox(height: SbSpace.x3),
                  ],
                ),
              ),
            ),
            // Pinned action bar: the primary action must never scroll away.
            // On a 640 dp phone the fields fill the sheet, so an in-scroll CTA
            // meant "add a subscription" required a scroll first.
            Container(
              padding: const EdgeInsets.fromLTRB(
                SbSpace.page,
                SbSpace.x3,
                SbSpace.page,
                SbSpace.x3,
              ),
              decoration: const BoxDecoration(
                color: SbColors.surface,
                border: Border(top: BorderSide(color: SbColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: _saving ? 'Adding…' : 'Add to burn tracker',
                      icon: _saving ? null : Icons.add_rounded,
                      trailing: _priceTrailing(),
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                  const SizedBox(height: SbSpace.x2),
                  Text(
                    'Stored on this device only. No account, no upload.',
                    style: SbType.micro.copyWith(
                      fontSize: 8,
                      color: SbColors.textMuted,
                      letterSpacing: 0.02,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `month` / `year` / `week` — "per monthly period" was a tautology.
  static String _periodNoun(BillingCycle cycle) => switch (cycle) {
        BillingCycle.weekly => 'week',
        BillingCycle.monthly => 'month',
        BillingCycle.yearly => 'year',
      };

  String _priceTrailing() {
    final amount = parseAmount(_priceController.text);
    if (amount == null || amount <= 0) return '—';
    final monthly = _cycle == BillingCycle.yearly
        ? amount / 12
        : amount * _cycle.monthlyFactor;
    return '${_currency.format(monthly.roundToDouble())} /mo';
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.toolCount,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int toolCount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: SbType.body.copyWith(fontSize: 13, color: SbColors.text),
      decoration: InputDecoration(
        hintText: toolCount > 0
            ? 'Search $toolCount tools — ChatGPT, Netflix, Figma…'
            : 'Search the catalogue…',
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 18,
          color: SbColors.textMuted,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                color: SbColors.textMuted,
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
    );
  }
}

class _ToolGrid extends StatelessWidget {
  const _ToolGrid({
    required this.tools,
    required this.selectedId,
    required this.onSelected,
    required this.onClear,
  });

  final List<PresetTool> tools;
  final String? selectedId;
  final ValueChanged<PresetTool> onSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (tools.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: SbSpace.x5),
        child: Center(
          child: Text(
            'No preset matches that. Type a name below and add it manually.',
            textAlign: TextAlign.center,
            style: SbType.caption.copyWith(color: SbColors.textMuted),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: SbSpace.x2,
        crossAxisSpacing: SbSpace.x2,
        childAspectRatio: 0.82,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        final tool = tools[index];
        final selected = tool.id == selectedId;
        return _ToolCell(
          tool: tool,
          selected: selected,
          onTap: () => selected ? onClear() : onSelected(tool),
        );
      },
    );
  }
}

class _ToolCell extends StatelessWidget {
  const _ToolCell({
    required this.tool,
    required this.selected,
    required this.onTap,
  });

  final PresetTool tool;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${tool.name}, ${tool.category}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SbRadius.inner),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SbRadius.inner),
            color: selected
                ? SbColors.accent.withValues(alpha: 0.10)
                : SbColors.surfaceHi,
            border: Border.all(
              color: selected ? SbColors.accent : SbColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ToolTile(
                    mark: tool.monogram,
                    brandColor: Color(tool.brandColor),
                    size: 34,
                  ),
                  if (selected)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: const BoxDecoration(
                          color: SbColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 9,
                          color: Color(0xFF160800),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                tool.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: SbType.micro.copyWith(
                  fontSize: 7.5,
                  color: selected ? SbColors.accentWarm : SbColors.textSecondary,
                  letterSpacing: 0,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencyToggle extends StatelessWidget {
  const _CurrencyToggle({required this.value, required this.onChanged});

  final CurrencyCode value;
  final ValueChanged<CurrencyCode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: SbColors.surfaceHi,
        borderRadius: BorderRadius.circular(SbRadius.button),
        border: Border.all(color: SbColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final code in CurrencyCode.values)
            Semantics(
              button: true,
              selected: value == code,
              label: code.code,
              child: InkWell(
                onTap: () => onChanged(code),
                borderRadius: BorderRadius.circular(SbRadius.tile),
                child: Container(
                  width: 40,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(SbRadius.tile),
                    gradient: value == code ? SbGradients.burn : null,
                  ),
                  child: Text(
                    code.symbol,
                    style: SbType.moneyMd.copyWith(
                      fontSize: 15,
                      color: value == code
                          ? const Color(0xFF1A0800)
                          : SbColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: SbType.label.copyWith(color: SbColors.textMuted, fontSize: 9),
        ),
        const SizedBox(height: SbSpace.x2),
        child,
      ],
    );
  }
}
