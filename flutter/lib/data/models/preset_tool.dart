import 'billing_cycle.dart';
import 'currency.dart';

/// A catalogue entry served from Cloudflare R2 (`presets_v1.json`).
///
/// The catalogue is static content: 100+ tools with a sensible default price,
/// brand colour, monogram and a direct cancellation URL. It is cached for seven
/// days and bundled in the APK so first launch works offline.
class PresetTool {
  const PresetTool({
    required this.id,
    required this.name,
    required this.vendor,
    required this.monogram,
    required this.brandColor,
    required this.category,
    required this.defaultPrice,
    required this.currency,
    required this.cycle,
    required this.cancelUrl,
    required this.popular,
  });

  final String id;
  final String name;
  final String vendor;
  final String monogram;

  /// Parsed from the `#RRGGBB` string in the JSON.
  final int brandColor;

  final String category;
  final double defaultPrice;
  final CurrencyCode currency;
  final BillingCycle cycle;
  final String cancelUrl;
  final bool popular;

  factory PresetTool.fromJson(Map<String, dynamic> json) {
    return PresetTool(
      id: json['id'] as String,
      name: json['name'] as String,
      vendor: (json['vendor'] as String?) ?? '',
      monogram: (json['monogram'] as String?) ?? _fallbackMonogram(json['name'] as String),
      brandColor: parseHexColor(json['brandColor'] as String?),
      category: (json['category'] as String?) ?? 'other',
      defaultPrice: (json['defaultPrice'] as num?)?.toDouble() ?? 0,
      currency: CurrencyCode.fromStorage(
        ((json['currency'] as String?) ?? 'INR').toLowerCase(),
      ),
      cycle: BillingCycle.fromStorage(
        ((json['cycle'] as String?) ?? 'monthly').toLowerCase(),
      ),
      cancelUrl: (json['cancelUrl'] as String?) ?? '',
      popular: (json['popular'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'vendor': vendor,
        'monogram': monogram,
        'brandColor': hexFromColor(brandColor),
        'category': category,
        'defaultPrice': defaultPrice,
        'currency': currency.code,
        'cycle': cycle.name,
        'cancelUrl': cancelUrl,
        'popular': popular,
      };

  static int parseHexColor(String? hex) {
    if (hex == null) return 0xFF9A9AA4;
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return 0xFF9A9AA4;
    return cleaned.length <= 6 ? 0xFF000000 | value : value;
  }

  static String hexFromColor(int argb) {
    final rgb = argb & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static String _fallbackMonogram(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2 && words[1].isNotEmpty) {
      return (words[0][0] + words[1][0]).toUpperCase();
    }
    return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  }
}

/// The whole catalogue, plus where it came from — surfaced in the UI so a
/// stale cache is visible rather than silent.
class PresetCatalogue {
  const PresetCatalogue({
    required this.tools,
    required this.version,
    required this.fetchedAt,
    required this.fromCache,
  });

  final List<PresetTool> tools;
  final int version;
  final DateTime fetchedAt;
  final bool fromCache;

  /// Sentinel used before the first catalogue load completes.
  static final empty = PresetCatalogue(
    tools: const [],
    version: 0,
    fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
    fromCache: true,
  );

  List<PresetTool> get popular => tools.where((t) => t.popular).toList();

  List<PresetTool> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      // Curated order first (popular, in catalogue order), then the long tail
      // alphabetically. Indexed so the sort stays stable on every platform.
      final indexed = tools.asMap().entries.toList()
        ..sort((a, b) {
          if (a.value.popular != b.value.popular) {
            return a.value.popular ? -1 : 1;
          }
          if (a.value.popular) return a.key.compareTo(b.key);
          return a.value.name
              .toLowerCase()
              .compareTo(b.value.name.toLowerCase());
        });
      return indexed.map((e) => e.value).toList(growable: false);
    }
    final matches = tools.where((t) {
      return t.name.toLowerCase().contains(q) ||
          t.vendor.toLowerCase().contains(q) ||
          t.category.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return matches;
  }

  /// Serialised exactly in the CDN schema so the cache is byte-compatible
  /// with `presets_v1.json`.
  Map<String, dynamic> toJson() => {
        'version': version,
        'generatedAt': fetchedAt.toIso8601String(),
        'tools': tools.map((t) => t.toJson()).toList(growable: false),
      };

  factory PresetCatalogue.fromJson(
    Map<String, dynamic> json, {
    required bool fromCache,
    DateTime? fetchedAt,
  }) {
    final raw = (json['tools'] as List<dynamic>? ?? const []);
    final tools = raw
        .whereType<Map<String, dynamic>>()
        .map(PresetTool.fromJson)
        .toList(growable: false);
    return PresetCatalogue(
      tools: tools,
      version: (json['version'] as num?)?.toInt() ?? 1,
      fetchedAt: fetchedAt ?? DateTime.now(),
      fromCache: fromCache,
    );
  }
}

/// USD → INR, refreshed from the CDN and cached alongside the catalogue.
class ExchangeRates {
  const ExchangeRates({
    required this.inrPerUsd,
    required this.asOf,
    required this.fromCache,
  });

  final double inrPerUsd;
  final DateTime asOf;
  final bool fromCache;

  /// Conservative fallback. Slightly high is safer than low: it avoids
  /// under-reporting burn if the CDN is unreachable on first launch.
  static final fallback = ExchangeRates(
    inrPerUsd: 83,
    asOf: DateTime.fromMillisecondsSinceEpoch(0),
    fromCache: true,
  );

  factory ExchangeRates.fromJson(
    Map<String, dynamic> json, {
    required bool fromCache,
  }) {
    final rate = (json['inrPerUsd'] as num?)?.toDouble();
    return ExchangeRates(
      inrPerUsd: (rate == null || rate <= 0) ? 83 : rate,
      asOf: DateTime.tryParse((json['asOf'] as String?) ?? '') ?? DateTime.now(),
      fromCache: fromCache,
    );
  }
}
