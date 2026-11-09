import 'dart:convert';
import 'dart:io';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../core/clock.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/preset_tool.dart';

/// Everything the app needs from the network, with an offline path for each.
///
/// Design rule: the app is fully usable with the device in aeroplane mode. The
/// CDN only *improves* the preset catalogue and the FX rate; it is never on the
/// critical path of opening the app.
class CatalogueService {
  CatalogueService({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Cloudflare R2 public bucket, overridable from Remote Config so the
  /// endpoint can move without shipping a release.
  final String baseUrl;
  final http.Client _client;

  static const cacheTtl = Duration(days: 7);

  /// Live FX feed. No API key, USD base, updates daily; the app keeps a 24-hour
  /// cache so a real user is never billed against a rate frozen at build time.
  static const liveRatesUrl = 'https://open.er-api.com/v6/latest/USD';
  static const liveRatesTtl = Duration(hours: 24);
  static const _liveRatesKey = 'cache.fx.live.v1';
  static const _liveRatesStampKey = 'cache.fx.liveAt';

  static const _presetsKey = 'cache.presets.v1';
  static const _presetsStampKey = 'cache.presets.fetchedAt';
  static const _ratesKey = 'cache.rates.v1';

  static const _presetsAsset = 'assets/json/presets_v1.json';
  static const _ratesAsset = 'assets/json/rates.json';

  /// Bundled copy — always available, even on a cold install with no network.
  Future<PresetCatalogue> loadBundledCatalogue() async {
    final raw = await rootBundle.loadString(_presetsAsset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return PresetCatalogue.fromJson(json, fromCache: true);
  }

  Future<ExchangeRates> loadBundledRates() async {
    final raw = await rootBundle.loadString(_ratesAsset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return ExchangeRates.fromJson(json, fromCache: true);
  }

  /// Loads the catalogue, preferring a fresh CDN copy, then a ≤7-day cache,
  /// then the asset bundle. Never throws — a failing network is a normal state.
  Future<CatalogueSnapshot> load({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedAt = DateTime.tryParse(prefs.getString(_presetsStampKey) ?? '');
    final cacheFresh = cachedAt != null &&
        DateTime.now().difference(cachedAt) < cacheTtl &&
        prefs.containsKey(_presetsKey);

    if (!forceRefresh && cacheFresh) {
      final cached = _decodeCatalogue(prefs.getString(_presetsKey));
      if (cached != null) {
        return CatalogueSnapshot(
          catalogue: cached,
          rates: await _loadRates(prefs, preferCache: true),
          source: CatalogueSource.cache,
        );
      }
    }

    try {
      final fetched = await _fetchCatalogue();
      if (fetched != null) {
        await prefs.setString(_presetsKey, jsonEncode(fetched.toJson()));
        await prefs.setString(_presetsStampKey, DateTime.now().toIso8601String());
        return CatalogueSnapshot(
          catalogue: fetched,
          rates: await _loadRates(prefs, preferCache: false),
          source: CatalogueSource.cdn,
        );
      }
    } on SocketException {
      // offline: fall through to cache/asset
    } on http.ClientException {
      // dns / connection reset: fall through
    } on FormatException {
      // a malformed payload must never brick the catalogue
    }

    final cached = _decodeCatalogue(prefs.getString(_presetsKey));
    if (cached != null) {
      return CatalogueSnapshot(
        catalogue: cached,
        rates: await _loadRates(prefs, preferCache: true),
        source: CatalogueSource.cache,
      );
    }

    return CatalogueSnapshot(
      catalogue: await loadBundledCatalogue(),
      rates: await loadBundledRates(),
      source: CatalogueSource.bundled,
    );
  }

  /// Real exchange rate, newest first:
  /// live feed (≤24 h) → live fetch → CDN rate file → cached → bundled.
  Future<ExchangeRates> _loadRates(
    SharedPreferences prefs, {
    required bool preferCache,
  }) async {
    final stamp = DateTime.tryParse(prefs.getString(_liveRatesStampKey) ?? '');
    final liveFresh = stamp != null &&
        SbClock.now().difference(stamp) < liveRatesTtl &&
        prefs.containsKey(_liveRatesKey);

    if (liveFresh) {
      final live = _decodeLiveRates(prefs.getString(_liveRatesKey));
      if (live != null) return live;
    }

    final fetched = await _fetchLiveRates(prefs);
    if (fetched != null) return fetched;

    // CDN file (refreshed by the cron worker) is the next best thing.
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/rates.json'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        await prefs.setString(_ratesKey, response.body);
        return ExchangeRates.fromJson(json, fromCache: false);
      }
    } catch (_) {
      // offline — fall through
    }

    final cached = prefs.getString(_ratesKey);
    if (cached != null) {
      final parsed = _decodeRates(cached);
      if (parsed != null) return parsed;
    }
    final staleLive = _decodeLiveRates(prefs.getString(_liveRatesKey));
    return staleLive ?? loadBundledRates();
  }

  Future<ExchangeRates?> _fetchLiveRates(SharedPreferences prefs) async {
    try {
      final response = await _client
          .get(Uri.parse(liveRatesUrl))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final rates = ExchangeRates.fromErApi(json);
      if (rates == null) return null;
      await prefs.setString(_liveRatesKey, response.body);
      await prefs.setString(
        _liveRatesStampKey,
        SbClock.now().toIso8601String(),
      );
      return rates;
    } catch (_) {
      return null;
    }
  }

  ExchangeRates? _decodeLiveRates(String? raw) {
    if (raw == null) return null;
    try {
      return ExchangeRates.fromErApi(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<PresetCatalogue?> _fetchCatalogue() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/presets_v1.json'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final catalogue = PresetCatalogue.fromJson(
      json,
      fromCache: false,
      fetchedAt: DateTime.now(),
    );
    // A payload with no tools is worse than the bundled copy.
    return catalogue.tools.isEmpty ? null : catalogue;
  }

  PresetCatalogue? _decodeCatalogue(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final catalogue = PresetCatalogue.fromJson(json, fromCache: true);
      return catalogue.tools.isEmpty ? null : catalogue;
    } catch (_) {
      return null;
    }
  }

  ExchangeRates? _decodeRates(String raw) {
    try {
      return ExchangeRates.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
        fromCache: true,
      );
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}

enum CatalogueSource { cdn, cache, bundled }

class CatalogueSnapshot {
  const CatalogueSnapshot({
    required this.catalogue,
    required this.rates,
    required this.source,
  });

  final PresetCatalogue catalogue;
  final ExchangeRates rates;
  final CatalogueSource source;

  CatalogueSnapshot copyWith({ExchangeRates? rates}) => CatalogueSnapshot(
        catalogue: catalogue,
        rates: rates ?? this.rates,
        source: source,
      );
}

/// Values that must change without a Play Store release.
///
/// Remote Config is fetched at most once per 12 hours and every read has a
/// baked-in default, so the app works before the first fetch completes.
class RemoteConfigService {
  RemoteConfigService(this._config);

  final FirebaseRemoteConfig _config;

  static const _defaults = <String, dynamic>{
    'cdn_base_url': 'https://pub-8fbd857d2069417ab8436546106f26b3.r2.dev',
    // Public OneSignal app id (not a secret). A --dart-define or the Remote
    // Config console value overrides it without a code change.
    'onesignal_app_id': String.fromEnvironment(
      'ONESIGNAL_APP_ID',
      defaultValue: '060140bf-e174-4f44-85d2-f5757dfdbd35',
    ),
    'smart_reminders': true,
    'roast_tone': 'savage',
  };

  static const minimumFetchInterval = Duration(hours: 12);

  Future<void> initialize() async {
    await _config.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        minimumFetchInterval: minimumFetchInterval,
      ),
    );
    await _config.setDefaults(_defaults);
    try {
      await _config.fetchAndActivate();
    } catch (error) {
      // Offline first launch is expected — defaults are already applied.
      debugPrint('Remote Config fetch skipped: $error');
    }
  }

  String get cdnBaseUrl =>
      _config.getString('cdn_base_url').ifEmpty(_defaults['cdn_base_url'] as String);

  String get oneSignalAppId => _config.getString('onesignal_app_id');

  bool get smartReminders => _config.getBool('smart_reminders');
}

extension _IfEmpty on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
