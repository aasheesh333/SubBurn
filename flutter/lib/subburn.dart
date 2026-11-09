/// SubBurn — public package surface.
///
/// The app is assembled from these pieces; tests import this barrel rather
/// than reaching into `lib/src` paths.
library;

export 'app.dart';
export 'core/theme/app_theme.dart';
export 'core/theme/theme_tokens.dart';
export 'core/utils/formatters.dart';
export 'data/hive/local_adapters.dart';
export 'data/models/billing_cycle.dart';
export 'data/models/currency.dart';
export 'data/models/preset_tool.dart';
export 'data/models/subscription.dart';
export 'data/models/usage_guilt.dart';
export 'data/repositories/subscription_repository.dart';
export 'features/studio/roast_engine.dart';
export 'features/studio/viral_receipt_screen.dart';
export 'services/catalogue_service.dart';
export 'services/share_service.dart';
export 'state/providers.dart';
export 'widgets/burn_hero_card.dart';
export 'widgets/money_text.dart';
export 'widgets/primary_button.dart';
export 'widgets/receipt_card.dart';
export 'widgets/segment_pills.dart';
export 'widgets/status_badge.dart';
export 'widgets/surface_card.dart';
export 'widgets/tool_tile.dart';
