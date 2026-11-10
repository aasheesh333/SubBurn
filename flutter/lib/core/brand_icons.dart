import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/widgets.dart';

/// Real platform logos for the preset catalogue.
///
/// Monogram tiles were trademark-safe but unreadable: four tools starting with
/// "N" all looked the same. The preset catalogue now renders the vendor's own
/// brand mark where Font Awesome has one (CC BY 4.0 brand icons) and falls back
/// to a category glyph, then to the monogram, so a custom entry still has an
/// identity.
///
/// Mapping is keyed on the vendor id so a renamed preset keeps its logo.
abstract final class BrandIcons {
  /// Best available logo for a subscription row.
  ///
  /// Order matters: an explicit preset id wins, then the tool's own name, and
  /// only then the category glyph. Returning the category first meant every row
  /// showed the same "ai" robot, which is what made the list unreadable.
  static IconData? resolve({
    String? presetId,
    String? name,
    String? category,
  }) {
    final byId = _byId[presetId];
    if (byId != null) return byId;
    return forName(name, category: category);
  }

  /// Resolves a logo from the tool's display name, so a row keeps its real brand
  /// mark even when it was added before preset ids were stored, or imported
  /// without one. Falls back to the category glyph.
  static IconData? forName(String? name, {String? category}) {
    if (name == null || name.trim().isEmpty) return _byCategory[category];
    final key = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .split(' ')
        .firstWhere((w) => w.isNotEmpty, orElse: () => '');
    // Longest alias first so "github copilot" matches before "github".
    for (final alias in _aliases.keys) {
      if (name.toLowerCase().contains(alias)) return _aliases[alias]!;
    }
    return _byId[key] ?? _byCategory[category];
  }

  /// Name fragment -> icon. Ordered by specificity.
  static final Map<String, IconData> _aliases = {
    'chatgpt': FontAwesomeIcons.openai.data,
    'openai': FontAwesomeIcons.openai.data,
    'claude': _byId['claude']!,
    'cursor': _byId['cursor']!,
    'copilot': FontAwesomeIcons.github.data,
    'midjourney': _byId['midjourney']!,
    'perplexity': _byId['perplexity']!,
    'gemini': _byId['gemini']!,
    'grok': _byId['grok']!,
    'deepseek': _byId['deepseek']!,
    'mistral': _byId['mistral']!,
    'notion': FontAwesomeIcons.notion.data,
    'jasper': _byId['jasper']!,
    'grammarly': _byId['grammarly']!,
    'quillbot': _byId['quillbot']!,
    'replit': _byId['replit']!,
    'windsurf': _byId['windsurf']!,
    'lovable': _byId['lovable']!,
    'bolt': _byId['bolt']!,
    'raycast': _byId['raycast']!,
    'warp': _byId['warp']!,
    'sentry': _byId['sentry']!,
    'vercel': _byId['vercel']!,
    'netlify': _byId['netlify']!,
    'supabase': _byId['supabase']!,
    'railway': _byId['railway']!,
    'planetscale': _byId['planetscale']!,
    'mongodb': _byId['mongodb']!,
    'cloudflare': _byId['cloudflare']!,
    'digitalocean': _byId['digitalocean']!,
    'render': _byId['render']!,
    'posthog': _byId['posthog']!,
    'mixpanel': _byId['mixpanel']!,
    'datadog': _byId['datadog']!,
    'figma': FontAwesomeIcons.figma.data,
    'framer': _byId['framer']!,
    'webflow': _byId['webflow']!,
    'sketch': _byId['sketch']!,
    'freepik': _byId['freepik']!,
    'shutterstock': _byId['shutterstock']!,
    'miro': _byId['miro']!,
    'loom': _byId['loom']!,
    'descript': _byId['descript']!,
    'riverside': _byId['riverside']!,
    'otter': _byId['otter']!,
    'elevenlabs': _byId['elevenlabs']!,
    'suno': _byId['suno']!,
    'runway': _byId['runway']!,
    'heygen': _byId['heygen']!,
    'synthesia': _byId['synthesia']!,
    'capcut': _byId['capcut']!,
    'filmora': _byId['filmora']!,
    'netflix': _byId['netflix']!,
    'spotify': FontAwesomeIcons.spotify.data,
    'youtube': FontAwesomeIcons.youtube.data,
    'hotstar': _byId['disney']!,
    'prime video': FontAwesomeIcons.amazon.data,
    'prime': FontAwesomeIcons.amazon.data,
    'amazon': FontAwesomeIcons.amazon.data,
    'zee5': _byId['zee5']!,
    'sonyliv': _byId['sonyliv']!,
    'audible': _byId['audible']!,
    'kindle': _byId['kindle']!,
    'medium': FontAwesomeIcons.medium.data,
    'substack': _byId['substack']!,
    'linkedin': FontAwesomeIcons.linkedin.data,
    'duolingo': FontAwesomeIcons.duolingo.data,
    'coursera': _byId['coursera']!,
    'skillshare': _byId['skillshare']!,
    'headspace': _byId['headspace']!,
    'calm': _byId['calm']!,
    'strava': _byId['strava']!,
    'cult': _byId['cult']!,
    'healthify': _byId['healthifyme']!,
    'swiggy': _byId['swiggy']!,
    'zomato': _byId['zomato']!,
    'dropbox': FontAwesomeIcons.dropbox.data,
    'google one': FontAwesomeIcons.googleDrive.data,
    'google workspace': FontAwesomeIcons.google.data,
    'google': FontAwesomeIcons.google.data,
    'icloud': _byId['icloud']!,
    'apple': FontAwesomeIcons.apple.data,
    '1password': _byId['1password']!,
    'bitwarden': _byId['bitwarden']!,
    'nordvpn': _byId['nordvpn']!,
    'expressvpn': _byId['expressvpn']!,
    'proton': _byId['proton']!,
    'microsoft': FontAwesomeIcons.microsoft.data,
    'slack': FontAwesomeIcons.slack.data,
    'zoom': FontAwesomeIcons.zoom.data,
    'linear': _byId['linear']!,
    'asana': _byId['asana']!,
    'clickup': _byId['clickup']!,
    'monday': _byId['monday']!,
    'trello': FontAwesomeIcons.trello.data,
    'airtable': _byId['airtable']!,
    'hubspot': FontAwesomeIcons.hubspot.data,
    'zendesk': _byId['zendesk']!,
    'intercom': _byId['intercom']!,
    'shopify': FontAwesomeIcons.shopify.data,
    'todoist': _byId['todoist']!,
    'obsidian': _byId['obsidian']!,
    'evernote': _byId['evernote']!,
  };

  /// Brands available in Font Awesome Free. Anything missing here (Netflix,
  /// Adobe, Canva, NVIDIA, Udemy) uses the category glyph instead of a wrong
  /// logo.
  static final Map<String, IconData> _byId = {
    'chatgpt': FontAwesomeIcons.openai.data,
    'claude': FontAwesomeIcons.robot.data,
    'cursor': FontAwesomeIcons.code.data,
    'copilot': FontAwesomeIcons.github.data,
    'midjourney': FontAwesomeIcons.palette.data,
    'perplexity': FontAwesomeIcons.searchengin.data,
    'gemini': FontAwesomeIcons.google.data,
    'grok': FontAwesomeIcons.xTwitter.data,
    'deepseek': FontAwesomeIcons.brain.data,
    'mistral': FontAwesomeIcons.wind.data,
    'poe': FontAwesomeIcons.comments.data,
    'notion': FontAwesomeIcons.notion.data,
    'jasper': FontAwesomeIcons.wandMagicSparkles.data,
    'copy': FontAwesomeIcons.copy.data,
    'writesonic': FontAwesomeIcons.penNib.data,
    'grammarly': FontAwesomeIcons.spellCheck.data,
    'quillbot': FontAwesomeIcons.feather.data,
    'replit': FontAwesomeIcons.terminal.data,
    'windsurf': FontAwesomeIcons.wind.data,
    'lovable': FontAwesomeIcons.heart.data,
    'v0': FontAwesomeIcons.triangleExclamation.data,
    'bolt': FontAwesomeIcons.bolt.data,
    'tabnine': FontAwesomeIcons.tableCells.data,
    'supermaven': FontAwesomeIcons.rocket.data,
    'raycast': FontAwesomeIcons.squarePollVertical.data,
    'warp': FontAwesomeIcons.terminal.data,
    'sentry': FontAwesomeIcons.bug.data,
    'vercel': FontAwesomeIcons.play.data,
    'netlify': FontAwesomeIcons.diamond.data,
    'supabase': FontAwesomeIcons.database.data,
    'railway': FontAwesomeIcons.train.data,
    'planetscale': FontAwesomeIcons.earthAmericas.data,
    'neon': FontAwesomeIcons.database.data,
    'mongodb': FontAwesomeIcons.leaf.data,
    'cloudflare': FontAwesomeIcons.cloudflare.data,
    'digitalocean': FontAwesomeIcons.digitalOcean.data,
    'fly': FontAwesomeIcons.jetFighter.data,
    'render': FontAwesomeIcons.server.data,
    'posthog': FontAwesomeIcons.chartLine.data,
    'mixpanel': FontAwesomeIcons.chartColumn.data,
    'amplitude': FontAwesomeIcons.waveSquare.data,
    'datadog': FontAwesomeIcons.dog.data,
    'figma': FontAwesomeIcons.figma.data,
    'framer': FontAwesomeIcons.objectGroup.data,
    'webflow': FontAwesomeIcons.webflow.data,
    'sketch': FontAwesomeIcons.penRuler.data,
    'affinity': FontAwesomeIcons.layerGroup.data,
    'freepik': FontAwesomeIcons.image.data,
    'envato': FontAwesomeIcons.envelopeOpenText.data,
    'shutterstock': FontAwesomeIcons.camera.data,
    'miro': FontAwesomeIcons.arrowsUpDownLeftRight.data,
    'loom': FontAwesomeIcons.video.data,
    'descript': FontAwesomeIcons.microphone.data,
    'riverside': FontAwesomeIcons.podcast.data,
    'otter': FontAwesomeIcons.closedCaptioning.data,
    'elevenlabs': FontAwesomeIcons.waveSquare.data,
    'suno': FontAwesomeIcons.music.data,
    'udio': FontAwesomeIcons.icons.data,
    'runway': FontAwesomeIcons.film.data,
    'luma': FontAwesomeIcons.video.data,
    'heygen': FontAwesomeIcons.userTie.data,
    'synthesia': FontAwesomeIcons.clapperboard.data,
    'capcut': FontAwesomeIcons.scissors.data,
    'filmora': FontAwesomeIcons.film.data,
    'davinci': FontAwesomeIcons.photoFilm.data,
    'netflix': FontAwesomeIcons.tv.data,
    'spotify': FontAwesomeIcons.spotify.data,
    'youtube': FontAwesomeIcons.youtube.data,
    'disney': FontAwesomeIcons.wandMagic.data,
    'prime': FontAwesomeIcons.amazon.data,
    'amazon': FontAwesomeIcons.amazon.data,
    'jiocinema': FontAwesomeIcons.play.data,
    'zee5': FontAwesomeIcons.tv.data,
    'sonyliv': FontAwesomeIcons.tv.data,
    'aha': FontAwesomeIcons.film.data,
    'apple': FontAwesomeIcons.apple.data,
    'iCloud': FontAwesomeIcons.cloud.data,
    'icloud': FontAwesomeIcons.cloud.data,
    'audible': FontAwesomeIcons.headphones.data,
    'kindle': FontAwesomeIcons.bookOpen.data,
    'medium': FontAwesomeIcons.medium.data,
    'substack': FontAwesomeIcons.newspaper.data,
    'linkedin': FontAwesomeIcons.linkedin.data,
    'x': FontAwesomeIcons.xTwitter.data,
    'duolingo': FontAwesomeIcons.duolingo.data,
    'coursera': FontAwesomeIcons.graduationCap.data,
    'skillshare': FontAwesomeIcons.chalkboardUser.data,
    'headspace': FontAwesomeIcons.spa.data,
    'calm': FontAwesomeIcons.moon.data,
    'strava': FontAwesomeIcons.personRunning.data,
    'cult': FontAwesomeIcons.dumbbell.data,
    'healthifyme': FontAwesomeIcons.heartPulse.data,
    'swiggy': FontAwesomeIcons.bowlFood.data,
    'zomato': FontAwesomeIcons.utensils.data,
    'dropbox': FontAwesomeIcons.dropbox.data,
    'google': FontAwesomeIcons.googleDrive.data,
    'googleone': FontAwesomeIcons.googleDrive.data,
    '1password': FontAwesomeIcons.key.data,
    'bitwarden': FontAwesomeIcons.shieldHalved.data,
    'nordvpn': FontAwesomeIcons.shieldHalved.data,
    'expressvpn': FontAwesomeIcons.shieldHalved.data,
    'proton': FontAwesomeIcons.lock.data,
    'workspace': FontAwesomeIcons.google.data,
    'microsoft365': FontAwesomeIcons.microsoft.data,
    'slack': FontAwesomeIcons.slack.data,
    'zoom': FontAwesomeIcons.zoom.data,
    'linear': FontAwesomeIcons.circleNodes.data,
    'asana': FontAwesomeIcons.listCheck.data,
    'clickup': FontAwesomeIcons.listCheck.data,
    'monday': FontAwesomeIcons.calendarCheck.data,
    'trello': FontAwesomeIcons.trello.data,
    'airtable': FontAwesomeIcons.table.data,
    'hubspot': FontAwesomeIcons.hubspot.data,
    'zendesk': FontAwesomeIcons.headset.data,
    'intercom': FontAwesomeIcons.comments.data,
    'shopify': FontAwesomeIcons.shopify.data,
    'todoist': FontAwesomeIcons.listCheck.data,
    'obsidian': FontAwesomeIcons.gem.data,
    'evernote': FontAwesomeIcons.noteSticky.data,
    'bear': FontAwesomeIcons.paw.data,
  };

  /// Category fallback so an unmapped vendor still looks deliberate.
  static final Map<String, IconData> _byCategory = {
    'ai': FontAwesomeIcons.robot.data,
    'dev': FontAwesomeIcons.code.data,
    'design': FontAwesomeIcons.penNib.data,
    'productivity': FontAwesomeIcons.listCheck.data,
    'writing': FontAwesomeIcons.pen.data,
    'analytics': FontAwesomeIcons.chartLine.data,
    'video': FontAwesomeIcons.video.data,
    'streaming': FontAwesomeIcons.tv.data,
    'shopping': FontAwesomeIcons.cartShopping.data,
    'reading': FontAwesomeIcons.bookOpen.data,
    'social': FontAwesomeIcons.users.data,
    'education': FontAwesomeIcons.graduationCap.data,
    'health': FontAwesomeIcons.heartPulse.data,
    'storage': FontAwesomeIcons.hardDrive.data,
    'security': FontAwesomeIcons.shieldHalved.data,
    'work': FontAwesomeIcons.briefcase.data,
  };

  /// Two-letter fallback for a custom tool with no preset.
  static String monogramFor(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2 && words[1].isNotEmpty) {
      return (words[0][0] + words[1][0]).toUpperCase();
    }
    return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  }
}
