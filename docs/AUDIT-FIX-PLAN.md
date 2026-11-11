# Audit Fix Plan (systematic-debugging)

Evidence: 5 parallel read-only audits, 2026-11-11. Every finding cited file:line.
Rule: verify root cause in code before each fix; math fixes get failing tests first.

## P0 — crashes / money corruption / revenue-dead / privacy falsehoods
- [x] 1. Rewarded unit id dead: ads_service reads 'admob_interstitial_unit', defaults define 'admob_rewarded_unit' (3 agents confirmed)
- [x] 2. Rewarded load() completes before onAdLoaded → first tap always fails; debug test-id unreachable (guard before substitution)
- [x] 3. Debug builds request LIVE banner unit (?? prefers Remote Config over test id) → invalid-traffic policy violation
- [x] 4. Infinity price → edit sheet crash in initState (formatPlainAmount round() on Infinity); no upper bound on price input
- [x] 5. Weekly cycle + old start date → nextAfter returns PAST date → showDatePicker assert crash (initialDate < firstDate)
- [x] 6. Month clamp drift: Jan31 → Feb28 → Mar28 (advance re-clamps from previous, not anchor)
- [x] 7. Cycle toggle applies fresh 17% discount to user-typed yearly price (₹10,000/yr → ₹8,297/yr round trip)
- [x] 8. CycleConversion._round rounds to whole units ($9.99/mo → $10/mo) contradicting decimal-preservation rule
- [x] 9. Comma-decimal input '9,99' parsed as 999 (formatter allows comma, parser strips it)
- [x] 10. _saving latch never releases on failure; validation snackbar renders BEHIND modal sheet (invisible)
- [x] 11. Privacy contradictions: legal 'No ads today'; privacy.html 'no ads'/'no ad SDK'; analytics sends vendor while copy says no vendors
- [x] 12. Cancel-link launcher: no https allowlist (remote catalogue can inject arbitrary schemes), no try/catch
- [x] 13. Cold-start notification tap dropped (handleLaunchNotification before runApp/navigator exists)
- [x] 14. Hero amount uses dark-only SbGradients.heroAmount → white-on-white in light theme (default for many)
- [x] 15. Ghost-only filter trap: delete last ghost → false 'Nothing burning yet' empty state, no way out

## P1 — layout / overflow / theme leaks / UX bugs
- [x] 16. StatusBadge fixed 19px overflows at 200% scale; didUpdateWidget pulse ignores reduce-motion
- [x] 17. Hero header row overflow at 200% (no Flexible on delta)
- [x] 18. Rail card price unprotected at text scale; empty-rail card fixed height 64
- [x] 19. BannerAdRegion renders stray divider when no ad loads; banner is fixed 320x50 not adaptive
- [x] 20. IndexedStack doesn't mute tickers → pulse animates forever on hidden tabs; SbEntrance replays on scroll-back
- [x] 21. Light-mode: SurfaceCard ignores cardShadow (flat), FAB ctaGlow smudge, ToolTile glyph contrast collapse
- [x] 22. Receipt: MoneyText /yr suffix reads ambient theme (light leak in dark-locked card + PNG); meter bar gradient wins over themed color; roast block fill + ambient glows still ember under Mono/Gold
- [x] 23. Dead back button on Receipts tab (maybePop on root route); _unlockThemes no re-entrancy guard, onReward ref unguarded
- [x] 24. Detail reminder switch: setReminders runs even when permission denied → UI/storage desync
- [x] 25. Reminder diagnostics stale: pendingCount includes test notification 990001
- [x] 26. Ad privacy MANAGE silent dead button when form unavailable
- [x] 27. Edit sheet: monogram stale after rename; no duplicate-name check; save button scrolls away; no name maxLength; emoji monogram = lone surrogate
- [x] 28. Next-charge pickers forbid today; currency toggle injects '0' into empty field; dates never show year
- [x] 29. Delta computed from filtered list vs unfiltered total; '1 tools' pluralization; split-bar semantics double unit; dead RenewalCard off-by-one (delete)
- [x] 30. Detail countdown never ticks; delete flashes 'gone' screen before pop, no undo
- [x] 31. First launch blocks up to 8s on fetchAndActivate before runApp
- [x] 32. Settings read-modify-write race; unlockReceiptThemes fire-and-forget
- [x] 33. DST: formatRenewalDay off-by-one across spring-forward; workdaysInMonth miscount
- [x] 34. Touch targets: currency chip 32px, theme chips 40px; renewals double rescheduleAll; main.dart deep-link uses MaterialPageRoute not SbPageRoute
- [x] 35. Docs: local_adapters stale migration refs; ads_service stale doc; roast_tone never read; lifetimeIn doc contradiction

## Verification
- [x] New failing-first tests: billing cycle drift, nextAfter, conversion decimals, comma parse, adapter roundtrip, ads config keys
- [x] flutter analyze --fatal-infos clean
- [x] flutter test full suite (was 119) + overflow sweep + goldens refresh
- [x] Commit + push; confirm CI green

## Outcome (2026-11-11)
- All P0 and P1 items above fixed in code; 16 new regression tests in
  `test/audit_fixes_test.dart` (billing anchoring, nextAfter past-date guard,
  cent-preserving conversion, comma-decimal parsing, non-finite guard,
  grapheme monograms, DST-safe date math, ads config keys, Hive round-trip).
- Three pre-existing tests updated where they encoded the old buggy behaviour
  (whole-unit rounding in CycleConversion).
- Goldens regenerated after intentional visual changes (light hero gradient,
  per-theme card shadows, themed receipt artwork, scaled badge heights);
  every regenerated frame inspected by eye.
- privacy.html re-published to the R2 host with the ad/analytics corrections.
