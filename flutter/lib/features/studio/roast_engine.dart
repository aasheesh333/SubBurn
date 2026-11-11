import 'dart:math' as math;

import '../../data/models/currency.dart';

/// The deterministic, offline roast engine.
///
/// There is no AI API in the loop: the same subscription list always produces
/// the same roast, on every device, forever. That is a product feature (a
/// receipt you can compare) and a cost feature ($0 per share).
///
/// Inputs: total yearly burn, the AI share of it, the ghost share, and the tool
/// count. Tone is a constructor parameter and always savage in production —
/// there is no Remote Config wiring for it (an earlier comment claimed a
/// `roast_tone` key that no code ever read).
class RoastEngine {
  const RoastEngine({this.tone = RoastTone.savage});

  final RoastTone tone;

  static const _gymYear = 24250.0; // Mumbai gym, ~₹2,020/mo
  static const _iphone = 79900.0; // iPhone 17, India
  static const _goaTrip = 45000.0; // long weekend for two
  static const _chaiCup = 15.0; // cutting chai

  Roast generate(RoastInput input) {
    final band = _bandFor(input.yearlyInr);
    final templates = _templates[band]!;
    final seed = _seed(input, band);
    final template = templates[seed % templates.length];

    final line = _fill(template.line, input);
    return Roast(
      tier: template.tier,
      line: line,
      band: band,
      intensity: band.index + 1,
      templateId: '${band.name}_${seed % templates.length}',
      verdict: verdictFor(input),
    );
  }

  /// A single comparison line, chosen deterministically from the burn.
  String verdictFor(RoastInput input) {
    final yearly = input.yearlyInr;
    if (yearly < 6000) {
      return 'That is a very nice dinner you did not have.';
    }

    final options = <String>[
      _comparison(yearly, _gymYear, 'a Mumbai gym membership'),
      _comparison(yearly, _iphone, 'an iPhone 17'),
      _comparison(yearly, _goaTrip, 'a long weekend in Goa for two'),
      _comparison(yearly, _chaiCup, 'cups of cutting chai'),
    ];

    // Weighted toward the gym line: it is the one that lands at 58k.
    final weights = <int>[4, 2, 2, 1];
    final total = weights.fold<int>(0, (a, b) => a + b);
    var pick = _seedBase(input) % total;
    for (var i = 0; i < options.length; i++) {
      if (pick < weights[i]) return options[i];
      pick -= weights[i];
    }
    return options.first;
  }

  String _comparison(double yearly, double unit, String noun) {
    final count = yearly / unit;
    if (count < 1) return 'That is less than $noun.';
    if (count < 10) {
      final rounded = count >= 3 ? count.round().toString() : count.toStringAsFixed(1);
      final plural = rounded == '1' ? noun : _plural(noun);
      return 'That is $rounded $plural.';
    }
    return 'That is ${count.round()} × $noun.';
  }

  static String _plural(String noun) {
    const irregular = {
      'a Mumbai gym membership': 'years of a Mumbai gym membership',
      'an iPhone 17': 'iPhones',
      'a long weekend in Goa for two': 'long weekends in Goa for two',
      'cups of cutting chai': 'cups of cutting chai',
    };
    return irregular[noun] ?? '${noun}s';
  }

  String _fill(String template, RoastInput input) {
    final aiPct = (input.aiShare * 100).round();
    final ghostPct = input.ghostShare * 100;
    return template
        .replaceAll('{yearly}', input.currency.format(input.yearlyInr))
        .replaceAll('{monthly}', input.currency.format(input.yearlyInr / 12))
        .replaceAll('{count}', '${input.toolCount}')
        .replaceAll('{aiPct}', '$aiPct')
        .replaceAll(
          '{ghostPct}',
          (ghostPct - ghostPct.roundToDouble()).abs() < 0.05
              ? ghostPct.round().toString()
              : ghostPct.toStringAsFixed(1),
        );
  }

  RoastBand _bandFor(double yearlyInr) {
    if (yearlyInr < 5000) return RoastBand.freeTierRefugee;
    if (yearlyInr < 15000) return RoastBand.subscriptionCurious;
    if (yearlyInr < 35000) return RoastBand.subscriptionHoarder;
    if (yearlyInr < 60000) return RoastBand.siliconValleyPaypig;
    return RoastBand.aiIndustryPatron;
  }

  int _seed(RoastInput input, RoastBand band) =>
      _seedBase(input) ^ (band.index * 7919);

  /// FNV-1a over the rounded figures: stable across runs and platforms.
  int _seedBase(RoastInput input) {
    final key =
        '${input.yearlyInr.round()}|${input.toolCount}|${(input.aiShare * 1000).round()}|${input.ghostShare.toStringAsFixed(3)}|${tone.name}';
    var hash = 0x811C9DC5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  static final Map<RoastBand, List<_Template>> _templates = {
    RoastBand.freeTierRefugee: const [
      _Template(RoastBand.freeTierRefugee, 'FREE-TIER REFUGEE',
          '{yearly}/yr. You could have bought a decent dinner and called it a day.'),
      _Template(RoastBand.freeTierRefugee, 'FREE-TIER REFUGEE',
          'Paying {yearly}/yr to feel productive is still cheaper than therapy.'),
      _Template(RoastBand.freeTierRefugee, 'FREE-TIER REFUGEE',
          '{yearly}/yr — the price of two concert tickets and one personality.'),
      _Template(RoastBand.freeTierRefugee, 'FREE-TIER REFUGEE',
          'At {yearly}/yr you are not burning money, you are gently toasting it.'),
      _Template(RoastBand.freeTierRefugee, 'FREE-TIER REFUGEE',
          'Your burn is smaller than your Notion backlog. Genuinely impressive.'),
      _Template(RoastBand.freeTierRefugee, 'FREE-TIER REFUGEE',
          'You are one free trial away from becoming a finance influencer.'),
    ],
    RoastBand.subscriptionCurious: const [
      _Template(RoastBand.subscriptionCurious, 'SUBSCRIPTION CURIOUS',
          '{yearly}/yr on tools you only open when the Wi-Fi is down.'),
      _Template(RoastBand.subscriptionCurious, 'SUBSCRIPTION CURIOUS',
          '{count} tools, one wallet, zero regrets. That is the problem.'),
      _Template(RoastBand.subscriptionCurious, 'SUBSCRIPTION CURIOUS',
          '{yearly}/yr to automate a job you still do manually.'),
      _Template(RoastBand.subscriptionCurious, 'SUBSCRIPTION CURIOUS',
          'That is a scooter EMI for a scooter you would also never ride.'),
      _Template(RoastBand.subscriptionCurious, 'SUBSCRIPTION CURIOUS',
          '{yearly}/yr: the subscription equivalent of a gym membership you cancel in February.'),
      _Template(RoastBand.subscriptionCurious, 'SUBSCRIPTION CURIOUS',
          'Your tabs are free. Your {yearly}/yr habit is not.'),
    ],
    RoastBand.subscriptionHoarder: const [
      _Template(RoastBand.subscriptionHoarder, 'SUBSCRIPTION HOARDER',
          '{count} tools, {aiPct}% of the burn on AI, 0% on self-control.'),
      _Template(RoastBand.subscriptionHoarder, 'SUBSCRIPTION HOARDER',
          '{yearly}/yr — a seed round in your own procrastination.'),
      _Template(RoastBand.subscriptionHoarder, 'SUBSCRIPTION HOARDER',
          'You automated the busywork and kept the worry. Bargain at {yearly}/yr.'),
      _Template(RoastBand.subscriptionHoarder, 'SUBSCRIPTION HOARDER',
          '{yearly}/yr and the only thing you have scaled is your billing page.'),
      _Template(RoastBand.subscriptionHoarder, 'SUBSCRIPTION HOARDER',
          '{ghostPct}% ghost spend: you are paying rent on apps that do not live in your life.'),
      _Template(RoastBand.subscriptionHoarder, 'SUBSCRIPTION HOARDER',
          '{yearly}/yr buys a gym membership, a therapist, and still leaves chai money.'),
    ],
    RoastBand.siliconValleyPaypig: const [
      _Template(RoastBand.siliconValleyPaypig, 'SILICON VALLEY PAYPIG',
          'Paying {yearly}/yr to generate memes and fix center divs.'),
      _Template(RoastBand.siliconValleyPaypig, 'SILICON VALLEY PAYPIG',
          '{yearly}/yr for a stack that mostly writes boilerplate and apologises.'),
      _Template(RoastBand.siliconValleyPaypig, 'SILICON VALLEY PAYPIG',
          'You are funding the AI boom one monthly charge at a time. Thank you for your service.'),
      _Template(RoastBand.siliconValleyPaypig, 'SILICON VALLEY PAYPIG',
          '{aiPct}% of your burn is AI. Your brain is still the cheapest compute you own.'),
      _Template(RoastBand.siliconValleyPaypig, 'SILICON VALLEY PAYPIG',
          '{yearly}/yr: enough to hire a junior dev to do the same thing badly, in person.'),
      _Template(RoastBand.siliconValleyPaypig, 'SILICON VALLEY PAYPIG',
          'Your subscriptions have subscriptions. That is not a stack, that is a pyramid scheme.'),
    ],
    RoastBand.aiIndustryPatron: const [
      _Template(RoastBand.aiIndustryPatron, 'AI INDUSTRY PATRON',
          '{yearly}/yr — you could have bought a used car and still had petrol money.'),
      _Template(RoastBand.aiIndustryPatron, 'AI INDUSTRY PATRON',
          '{yearly}/yr is a small angel round in a startup that only sells you tabs.'),
      _Template(RoastBand.aiIndustryPatron, 'AI INDUSTRY PATRON',
          'At {yearly}/yr, your tools should at least be doing your taxes.'),
      _Template(RoastBand.aiIndustryPatron, 'AI INDUSTRY PATRON',
          'You are not a power user. You are a venture-funded customer segment.'),
      _Template(RoastBand.aiIndustryPatron, 'AI INDUSTRY PATRON',
          '{aiPct}% AI, {ghostPct}% ghost. The rest is hope.'),
      _Template(RoastBand.aiIndustryPatron, 'AI INDUSTRY PATRON',
          'You spent {yearly}/yr proving software is cheaper than hiring people. It is not.'),
    ],
  };
}

enum RoastTone { savage, dry, corporate }

enum RoastBand {
  freeTierRefugee('FREE-TIER REFUGEE'),
  subscriptionCurious('SUBSCRIPTION CURIOUS'),
  subscriptionHoarder('SUBSCRIPTION HOARDER'),
  siliconValleyPaypig('SILICON VALLEY PAYPIG'),
  aiIndustryPatron('AI INDUSTRY PATRON');

  const RoastBand(this.displayName);

  /// Human label. Never derive this from `.name`: camelCase upper-cased reads
  /// "FREETIERREFUGEE", which is what the empty receipt printed.
  final String displayName;
}

class RoastInput {
  const RoastInput({
    required this.yearlyInr,
    required this.monthlyInr,
    required this.ghostShare,
    required this.aiShare,
    required this.toolCount,
    required this.currency,
  });

  /// Burn in INR — the band thresholds are rupee-denominated.
  final double yearlyInr;
  final double monthlyInr;
  final double ghostShare;
  final double aiShare;
  final int toolCount;
  final CurrencyCode currency;
}

class Roast {
  const Roast({
    required this.tier,
    required this.line,
    required this.band,
    required this.intensity,
    required this.templateId,
    required this.verdict,
  });

  final String tier;
  final String line;
  final RoastBand band;

  /// 1..5, drives the five-bar meter on the card.
  final int intensity;

  /// Stable identifier of the chosen template — useful for analytics and tests.
  final String templateId;

  final String verdict;

  static Roast empty = Roast(
    tier: RoastBand.freeTierRefugee.displayName,
    line: 'Nothing is burning yet. Add a subscription and come back.',
    band: RoastBand.freeTierRefugee,
    intensity: 1,
    templateId: 'empty',
    verdict: 'That is a very nice dinner you did not have.',
  );

  double get intensityFraction => intensity / RoastBand.values.length;

  /// Deterministic per-input, used by tests to prove no RNG is involved.
  static int previewHashFor(double yearlyInr, int toolCount) {
    final key = '${yearlyInr.round()}|$toolCount';
    var hash = 0x811C9DC5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return math.max(hash, 1);
  }
}

class _Template {
  const _Template(this.band, this.tier, this.line);

  final RoastBand band;
  final String tier;
  final String line;
}
