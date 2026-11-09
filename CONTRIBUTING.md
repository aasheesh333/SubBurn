# Contributing

## Before you open a PR

```bash
cd flutter
flutter analyze --fatal-infos
flutter test
```

```bash
python3 tools/audit.py     # must print PASS
```

CI runs all three. A golden-test failure means a screen changed: open the diff,
decide whether the change was intended, and only then run
`flutter test test/screens_preview_test.dart --update-goldens`.

## Rules that are not negotiable

- **Nothing invents a number.** Screens read `burnSummaryProvider`. If a screen
  needs a new aggregate, add it to `BurnSummary` so there is still one source.
- **User data never leaves the device.** No Firestore, no upload, no auth. The
  only network calls are the static catalogue, the FX rate and Firebase config.
- **No exact alarms.** `AndroidScheduleMode.inexactAllowWhileIdle` only. Adding
  `USE_EXACT_ALARM` breaks Play submission.
- **The receipt is a pure node.** No `Theme`, no `MediaQuery`, no paint that
  escapes its 360 × 640 bounds.
- **Fonts ship, they do not download.** `GoogleFonts.config.allowRuntimeFetching`
  is false; faces come from `assets/google_fonts`.

## Tokens

`design-tokens.json` and `flutter/lib/core/theme/theme_tokens.dart` are
duplicated on purpose (no codegen step). If you change a token, change both and
say so in the PR. `index.html` is the visual source of truth — if the design
changes, change it there and re-run `tools/render.py`.
