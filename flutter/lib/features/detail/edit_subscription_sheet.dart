import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand_icons.dart';
import '../../core/theme/theme_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/billing_cycle.dart';
import '../../data/models/currency.dart';
import '../../data/models/cycle_conversion.dart';
import '../../data/models/subscription.dart';
import '../../data/models/usage_guilt.dart';
import '../../state/providers.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/segment_pills.dart';
import '../../widgets/tool_tile.dart';

/// Edit an existing subscription.
///
/// Before this the only editable fields were the two dates and the guilt flag:
/// a typo in a price could only be fixed by deleting the row and losing its
/// start date, which also broke lifetime spend and the renewal history. Name,
/// price, currency, cycle and guilt are all editable here; deleting stays in the
/// overflow menu where it belongs.
class EditSubscriptionSheet extends ConsumerStatefulWidget {
  const EditSubscriptionSheet({super.key, required this.subscription});

  final Subscription subscription;

  static Future<bool?> show(BuildContext context, Subscription subscription) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditSubscriptionSheet(subscription: subscription),
    );
  }

  @override
  ConsumerState<EditSubscriptionSheet> createState() =>
      _EditSubscriptionSheetState();
}

class _EditSubscriptionSheetState extends ConsumerState<EditSubscriptionSheet> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late BillingCycle _cycle;
  late CurrencyCode _currency;
  late UsageGuilt _guilt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.subscription;
    _name = TextEditingController(text: s.name);
    _price = TextEditingController(text: formatPlainAmount(s.amount));
    _cycle = s.cycle;
    _currency = s.currency;
    _guilt = s.guilt;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  void _switchCycle(BillingCycle next) {
    if (next == _cycle) return;
    final amount = parseAmount(_price.text) ?? 0;
    // No annual discount here: the stored amount is the real charge, so a plain
    // unit conversion is the only honest change. The 17 % discount belongs to
    // adding a plan, not to relabelling an existing one.
    final result = CycleConversion.convert(
      amount: amount,
      from: _cycle,
      to: next,
      discountApplied: false,
    );
    setState(() {
      _cycle = next;
      _price.text = formatPlainAmount(result.amount);
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final amount = parseAmount(_price.text) ?? 0;
    if (name.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              name.isEmpty ? 'Give it a name.' : 'Enter the real charge.',
            ),
          ),
        );
      return;
    }

    setState(() => _saving = true);
    final s = widget.subscription;
    final updated = s.copyWith(
      name: name,
      amount: amount,
      currency: _currency,
      cycle: _cycle,
      guilt: _guilt,
      brandColor: s.brandColor,
    );

    await ref.read(subscriptionsProvider.notifier).update(updated);

    if (!mounted) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.subscription;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
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
                children: [
                  ToolTile(
                    mark: s.monogram,
                    brandColor: Color(s.brandColor),
                    icon: BrandIcons.resolve(
                      presetId: s.presetId,
                      name: s.name,
                      category: s.category,
                    ),
                    size: 34,
                  ),
                  const SizedBox(width: SbSpace.x2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit subscription',
                          style: SbType.h3.copyWith(color: context.sb.text),
                        ),
                        Text(
                          '${s.vendor} · since ${formatChargeDate(s.startDate)}',
                          style: SbType.micro.copyWith(
                            fontSize: 8,
                            color: context.sb.textMuted,
                            letterSpacing: 0.02,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: Icon(Icons.close_rounded, color: context.sb.textSecondary),
                    tooltip: 'Close',
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
                    _Field(
                      label: 'Name',
                      child: TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        style: SbType.body.copyWith(
                          fontSize: 13,
                          color: context.sb.text,
                        ),
                        decoration: const InputDecoration(hintText: 'Name'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: SbSpace.x3),
                    _Field(
                      label: 'Price per ${_periodNoun(_cycle)}',
                      child: Row(
                        children: [
                          _CurrencyToggle(
                            value: _currency,
                            onChanged: (next) {
                              if (next == _currency) return;
                              final current = parseAmount(_price.text) ?? 0;
                              final rate = ref.read(ratesProvider).inrPerUsd;
                              final converted = next == CurrencyCode.usd
                                  ? current / rate
                                  : current * rate;
                              setState(() {
                                _currency = next;
                                _price.text = next == CurrencyCode.usd
                                    ? converted.toStringAsFixed(
                                        converted >= 100 ? 0 : 2,
                                      )
                                    : formatPlainAmount(
                                        converted.roundToDouble(),
                                      );
                              });
                            },
                          ),
                          const SizedBox(width: SbSpace.x2),
                          Expanded(
                            child: TextField(
                              controller: _price,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                              decoration: const InputDecoration(hintText: '0'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: SbSpace.x3),
                    _Field(
                      label: 'Billing cycle',
                      child: SegmentPills<BillingCycle>(
                        values: BillingCycle.values,
                        selected: _cycle,
                        labelOf: (c) => c.label,
                        onChanged: _switchCycle,
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
                      'Next charge ${formatChargeDate(s.nextBillingDate)} · '
                      'adjust the date from the detail screen.',
                      style: SbType.micro.copyWith(
                        fontSize: 8,
                        color: context.sb.textMuted,
                        letterSpacing: 0,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: SbSpace.x4),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        label: _saving ? 'Saving…' : 'Save changes',
                        icon: _saving ? null : Icons.check_rounded,
                        trailing: _monthlyTrailing(),
                        onPressed: _saving ? null : _save,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthlyTrailing() {
    final amount = parseAmount(_price.text);
    if (amount == null || amount <= 0) return '—';
    final monthly = amount * _cycle.monthlyFactor;
    return '${_currency.format(monthly.roundToDouble())} /mo';
  }

  static String _periodNoun(BillingCycle cycle) => switch (cycle) {
        BillingCycle.weekly => 'week',
        BillingCycle.monthly => 'month',
        BillingCycle.yearly => 'year',
      };
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
          style: SbType.label.copyWith(
            color: context.sb.textMuted,
            fontSize: 9,
          ),
        ),
        const SizedBox(height: SbSpace.x2),
        child,
      ],
    );
  }
}
