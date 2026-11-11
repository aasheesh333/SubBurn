import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand_icons.dart';
import '../../core/clock.dart';
import '../../core/theme/theme_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/billing_cycle.dart';
import '../../data/models/currency.dart';
import '../../data/models/cycle_conversion.dart';
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

  /// Returns the saved subscription, or null when the sheet was dismissed.
  static Future<Subscription?> show(
    BuildContext context, {
    PresetTool? initialPreset,
  }) {
    return showModalBottomSheet<Subscription?>(
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
  // Empty, not '0': a pre-filled zero looked like a real price and the CTA
  // chip read as a broken dash.
  final _priceController = TextEditingController();
  final _searchFocus = FocusNode();

  PresetTool? _preset;
  BillingCycle _cycle = BillingCycle.monthly;
  CurrencyCode _currency = CurrencyCode.inr;
  UsageGuilt _guilt = UsageGuilt.dailyDriver;
  String _query = '';
  bool _saving = false;

  /// Inline validation/save error. A SnackBar is invisible from inside a modal
  /// sheet — it renders on the page's Scaffold, *below* the sheet — so errors
  /// are shown inside the sheet's own pinned action bar instead.
  String? _error;

  late DateTime _startDate = SbClock.now();
  late DateTime _nextDate = _cycle.nextAfter(_startDate);
  bool _nextDateEdited = false;

  /// True while the price in the field is `12 × monthly × 0.83` rather than a
  /// number the user typed. Makes the Yearly toggle reversible: switching back
  /// to monthly divides by the same factor instead of compounding the discount.
  bool _yearlyDiscountApplied = false;

  /// The yearly price as the vendor actually charges it, when the user typed it
  /// (or a yearly preset supplied it). Toggling Yearly → Monthly → Yearly
  /// restores this exact number instead of inventing a fresh 17 % discount on
  /// money that was never discounted.
  double? _nativeYearlyAmount;

  /// Sanity ceiling for one charge. A paste of 310+ digits parses to Infinity,
  /// which used to crash the edit sheet (`Infinity.round()`); absurd-but-finite
  /// values are rejected too so no ledger total can become meaningless.
  static const double _maxPrice = 1000000000; // 1e9

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
      _yearlyDiscountApplied = false;
      _nativeYearlyAmount =
          preset.cycle == BillingCycle.yearly ? preset.defaultPrice : null;
      // Deliberately do NOT infer usage from the category. Picking Netflix
      // used to silently mark it "Barely Touch It", which inflated the ghost
      // percentage and changed the roast tier without the user saying anything.
      // Usage is a judgement only the user can make.
    });
  }

  void _clearPreset() {
    setState(() {
      _preset = null;
      _nameController.clear();
      _priceController.clear();
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

    // A yearly amount the user typed (or a yearly preset supplied) is the real
    // bill. Returning to yearly restores it verbatim — re-discounting it there
    // silently corrupted stored amounts (₹10,000/yr → ₹8,297/yr round trip).
    final restoreNative = next == BillingCycle.yearly &&
        !_yearlyDiscountApplied &&
        _nativeYearlyAmount != null;
    final result = restoreNative
        ? ConversionResult(_nativeYearlyAmount!, discountApplied: false)
        : CycleConversion.convert(
            amount: current,
            from: _cycle,
            to: next,
            discountApplied: _yearlyDiscountApplied,
          );

    setState(() {
      _cycle = next;
      _priceController.text = formatPlainAmount(result.amount);
      _yearlyDiscountApplied = result.discountApplied;
      if (!_nextDateEdited) {
        _nextDate = next.nextAfter(_startDate);
      }
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: SbClock.now(),
      helpText: 'When did this subscription start?',
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (!_nextDateEdited || !_nextDate.isAfter(SbClock.now())) {
        _nextDate = _cycle.nextAfter(_startDate);
        _nextDateEdited = false;
      }
    });
  }

  Future<void> _pickNextDate() async {
    final now = SbClock.now();
    // Today must be selectable: "it renews today" is the most common real
    // state, and the old tomorrow-floor pushed every such charge a day late.
    final firstDate = DateTime(now.year, now.month, now.day);
    var initial = _nextDate.isAfter(now) ? _nextDate : _cycle.nextAfter(_startDate);
    if (initial.isBefore(firstDate)) initial = _cycle.nextAfter(_startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365 * 3)),
      helpText: 'When is the next charge?',
    );
    if (picked == null) return;
    setState(() {
      _nextDate = picked;
      _nextDateEdited = true;
    });
  }

  void _switchCurrency(CurrencyCode next, double inrPerUsd) {
    if (next == _currency) return;
    final parsed = parseAmount(_priceController.text);
    setState(() {
      _currency = next;
      // An empty field stays empty: converting "nothing" used to inject a
      // pre-filled 0 that looked like a real price.
      if (parsed != null) {
        final converted =
            next == CurrencyCode.usd ? parsed / inrPerUsd : parsed * inrPerUsd;
        _priceController.text = next == CurrencyCode.usd
            ? converted.toStringAsFixed(converted >= 100 ? 0 : 2)
            : formatPlainAmount(converted.roundToDouble());
      }
      final native = _nativeYearlyAmount;
      if (native != null) {
        _nativeYearlyAmount =
            next == CurrencyCode.usd ? native / inrPerUsd : native * inrPerUsd;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    final price = parseAmount(_priceController.text);
    if (name.isEmpty || price == null || price <= 0 || !price.isFinite) {
      setState(() {
        _error = name.isEmpty
            ? 'Give the subscription a name first.'
            : 'Enter what it actually costs.';
      });
      return;
    }
    if (price > _maxPrice) {
      setState(() => _error = 'That price looks too large — check the amount.');
      return;
    }

    // Two rows for the same tool double the burn and the receipt. Warn instead
    // of silently allowing it, but do not block a genuinely separate plan.
    final existing = ref
        .read(subscriptionsProvider)
        .where((s) => s.name.toLowerCase() == name.toLowerCase())
        .toList();
    if (existing.isNotEmpty) {
      final proceed = await _confirmDuplicate(name);
      if (proceed != true) return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final preset = _preset;
    final subscription = Subscription(
      id: SubscriptionRepository.newId(),
      name: name,
      vendor: preset?.vendor ?? 'CUSTOM',
      monogram: preset?.monogram ?? monogramFor(name),
      brandColor: preset?.brandColor ?? 0xFF9A9AA4,
      amount: price,
      currency: _currency,
      cycle: _cycle,
      guilt: _guilt,
      category: preset?.category ?? 'other',
      startDate: _startDate,
      nextBillingDate: _nextDate,
      cancelUrl: preset?.cancelUrl ?? '',
      presetId: preset?.id,
    );

    try {
      await ref
          .read(subscriptionsProvider.notifier)
          .add(subscription, fromPreset: preset != null);
    } catch (error) {
      // Release the latch on failure: without this the CTA stayed disabled
      // at "Adding…" forever and the sheet was a dead end.
      debugPrint('Quick add failed: $error');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Please try again.';
        });
      }
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(subscription);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(catalogueProvider);
    final rates = ref.watch(ratesProvider);
    final catalogue = snapshot.value?.catalogue;
    final all = catalogue?.search(_query) ?? <PresetTool>[];
    // The sheet shows a 3-row preview by default; search reveals more. A
    // 124-tile wall pushes the form off-screen and reads as a directory.
    final results = _query.isEmpty
        ? all.take(12).toList(growable: false)
        : all.take(24).toList(growable: false);
    final hidden = all.length - results.length;
    final refreshing = ref.watch(catalogueRefreshingProvider);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: context.sb.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SbRadius.sheet),
          ),
          border: Border(top: BorderSide(color: context.sb.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: SbSpace.x2),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.sb.borderHi,
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
                          style: SbType.h2.copyWith(color: context.sb.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pick a tool, set the burn, log the guilt.',
                          style: SbType.body.copyWith(
                            color: context.sb.textSecondary,
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
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: context.sb.textSecondary,
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
                            color: context.sb.textMuted,
                            fontSize: 9,
                          ),
                        ),
                        const Spacer(),
                        if (snapshot.isLoading || refreshing)
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
                            color: context.sb.textMuted,
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
                        // Bounded so the identity card, list rows and receipt
                        // never receive a paragraph posing as a product name.
                        maxLength: 60,
                        style: SbType.body.copyWith(
                          fontSize: 13,
                          color: context.sb.text,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'e.g. ChatGPT Plus',
                          counterText: '',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: SbSpace.x3),
                    Row(
                      children: [
                        Expanded(
                          child: _Field(
                            label: 'Started',
                            child: _DateTile(
                              date: _startDate,
                              semanticLabel: 'Subscription start date',
                              onTap: _pickStartDate,
                            ),
                          ),
                        ),
                        const SizedBox(width: SbSpace.x2),
                        Expanded(
                          child: _Field(
                            label: 'Next charge',
                            child: _DateTile(
                              date: _nextDate,
                              semanticLabel: 'Next billing date',
                              highlighted: true,
                              onTap: _pickNextDate,
                            ),
                          ),
                        ),
                      ],
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
                                color: context.sb.text,
                              ),
                              decoration: const InputDecoration(
                                hintText: '0',
                              ),
                              onChanged: (text) => setState(() {
                                _yearlyDiscountApplied = false;
                                // Whatever the user types in yearly mode is the
                                // real bill; remember it so cycle toggles can
                                // restore it instead of re-discounting.
                                _nativeYearlyAmount =
                                    _cycle == BillingCycle.yearly
                                        ? parseAmount(text)
                                        : null;
                                _error = null;
                              }),
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
                    if (_preset != null)
                      Padding(
                        padding: const EdgeInsets.only(top: SbSpace.x2),
                        child: Text(
                          'Suggested price for ${_preset!.name} — edit it to '
                          'match your actual bill.',
                          style: SbType.micro.copyWith(
                            fontSize: 8,
                            color: context.sb.textMuted,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    const SizedBox(height: SbSpace.x2),
                    Text(
                      _guilt.isGhost
                          ? 'This one will be counted as ghost spend on your receipt.'
                          : 'Counted as active use. Ghost spend stays honest.',
                      style: SbType.caption.copyWith(color: context.sb.textMuted),
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
              decoration: BoxDecoration(
                color: context.sb.surface,
                border: Border(top: BorderSide(color: context.sb.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: SbSpace.x2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 14,
                            color: context.sb.danger,
                          ),
                          const SizedBox(width: SbSpace.x1),
                          Expanded(
                            child: Text(
                              _error!,
                              style: SbType.caption.copyWith(
                                color: context.sb.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                      color: context.sb.textMuted,
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

  /// Asks before adding a second row with the same name.
  Future<bool?> _confirmDuplicate(String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.sb.surfaceHi,
        title: Text('Already tracking $name', style: SbType.h3),
        content: Text(
          'You already have a $name subscription. Adding another one counts '
          'both — useful for two separate plans, wrong if this is a duplicate.',
          style: SbType.body.copyWith(color: context.sb.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ADD ANYWAY'),
          ),
        ],
      ),
    );
  }

  /// `month` / `year` / `week` — "per monthly period" was a tautology.
  static String _periodNoun(BillingCycle cycle) => switch (cycle) {
        BillingCycle.weekly => 'week',
        BillingCycle.monthly => 'month',
        BillingCycle.yearly => 'year',
      };

  /// The live price chip on the CTA. Null while the price is not meaningful,
  /// so the button shows just its label instead of a placeholder dash.
  String? _priceTrailing() {
    final amount = parseAmount(_priceController.text);
    if (amount == null || amount <= 0) return null;
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
      style: SbType.body.copyWith(fontSize: 13, color: context.sb.text),
      decoration: InputDecoration(
        hintText: toolCount > 0
            ? 'Search $toolCount tools — ChatGPT, Netflix, Figma…'
            : 'Search the catalogue…',
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 18,
          color: context.sb.textMuted,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                tooltip: 'Clear search',
                color: context.sb.textMuted,
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
            style: SbType.caption.copyWith(color: context.sb.textMuted),
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
                ? context.sb.accent.withValues(alpha: 0.10)
                : context.sb.surfaceHi,
            border: Border.all(
              color: selected ? context.sb.accent : context.sb.border,
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
                    icon: BrandIcons.forName(tool.name, category: tool.category),
                    platform: tool.name,
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
                        decoration: BoxDecoration(
                          color: context.sb.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 9,
                          color: context.sb.onAccent,
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
                  color: selected ? context.sb.accentWarm : context.sb.textSecondary,
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
        color: context.sb.surfaceHi,
        borderRadius: BorderRadius.circular(SbRadius.button),
        border: Border.all(color: context.sb.border),
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
                          ? context.sb.onAccent
                          : context.sb.textSecondary,
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

/// Tappable date row used for start / next-charge. Real dates, not derived
/// display values: reminders and lifetime spend both hang off them.
class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.date,
    required this.onTap,
    required this.semanticLabel,
    this.highlighted = false,
  });

  final DateTime date;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$semanticLabel: ${formatChargeDate(date)}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SbRadius.button),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: SbSpace.x3),
          decoration: BoxDecoration(
            color: context.sb.surfaceHi,
            borderRadius: BorderRadius.circular(SbRadius.button),
            border: Border.all(
              color: highlighted ? context.sb.accent.withValues(alpha: 0.55) : context.sb.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  formatChargeDate(date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SbType.moneySm.copyWith(
                    fontSize: 12,
                    color: highlighted ? context.sb.accentWarm : context.sb.text,
                  ),
                ),
              ),
              Icon(
                Icons.calendar_today_rounded,
                size: 12,
                color: context.sb.textMuted,
              ),
            ],
          ),
        ),
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
          style: SbType.label.copyWith(color: context.sb.textMuted, fontSize: 9),
        ),
        const SizedBox(height: SbSpace.x2),
        child,
      ],
    );
  }
}
