# Reminders — verification and known limits

Everything here was checked against the shipping code and, where possible, the
built APK. "Verified" means the claim is provable from the artefact; "device
only" means no test harness can prove it and it must be confirmed on a phone.

## Verified in code + APK

| Claim | Evidence |
|---|---|
| Manifest declares everything the plugin needs | `POST_NOTIFICATIONS`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED` + both receivers (`ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver`) with `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `QUICKBOOT_POWERON`, `com.htc.intent.action.QUICKBOOT_POWERON` — all confirmed present in the merged `AndroidManifest.xml` inside the release APK |
| Small icon exists and survives R8 | `drawable/ic_stat_subburn.xml` (vector) kept via `res/raw/keep.xml`; confirmed in `resources.arsc` of the release APK |
| No exact-alarm permission | Scheduled with `AndroidScheduleMode.inexactAllowWhileIdle`; manifest has no `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`. Play-safe, and a renewal reminder does not need second precision |
| Alarms survive reboot and app update | Boot receiver above; `rescheduleAll()` also runs on shell first frame and on every resume |
| Times are timezone-safe | Fire times are built from absolute epoch millis (`TZDateTime.fromMillisecondsSinceEpoch`), so a failed timezone lookup cannot shift alarms; DST-correct because the instant is fixed |
| No stale alarms | A slot is skipped if its fire time is already inside the 1-minute guard; overdue renewals roll forward before scheduling |
| Two reminders per subscription, independently | Slots 0 (48 h) and 1 (24 h); one slot failing does not block the other |
| Notification ids are stable and 32-bit safe | FNV-1a folded into 0…1.999e9, ×10 + slot; unit-tested for range, slot separation and collision rate (5 000 ids → < 5 collisions) |
| Tapping a reminder opens its subscription | Payload is the subscription id; cold-start replay runs after the first frame (the navigator exists by then) |
| Permission is read back, not assumed | `refreshPermission()` after every prompt; a later grant in system settings heals without a reinstall |
| A silenced channel is detected | `status == channelBlocked` when app notifications are allowed but our channel's importance is `none` — Android reports the app as enabled in that state, which used to read "ACTIVE" while nothing could be delivered |
| Permanent denial has a way out | ALLOW now prompts, then falls back to the system notification settings screen (Android silently refuses re-prompts after two declines) |
| Diagnostics never lie | Controls shows queued count, BLOCKED / ACTIVE / IDLE, and a channel-specific message; the test-notification buttons were removed |

## Device-only (cannot be proven by tests)

These are OS/OEM behaviours, not app logic:

1. **Battery optimisation / aggressive OEM task killers.** Xiaomi (MIUI), Oppo/Realme (ColorOS), Vivo (Funtouch), Samsung and Huawei throttle or drop `AlarmManager` alarms when the app is force-stopped or not whitelisted. Inexact alarms are the most affected. Mitigation in app: re-arm on every launch and resume, so a dropped reminder is repaired the next time the app opens. **Full mitigation requires the user to exempt SubBurn from battery optimisation** — the app cannot grant that itself, and asking for it unprompted is a Play policy risk.
2. **Force-stop.** If the user force-stops the app (or an OEM does it), Android cancels its alarms until the app is launched again. Nothing an app can do.
3. **Do Not Disturb / silent mode.** The channel uses `Importance.high` with sound and vibration, but a device in DND (or the channel set to silent by the user) will deliver silently.
4. **Exact delivery time.** Inexact alarms fire *around* the target, typically within minutes but under Doze up to ~15 minutes later. This is deliberate: exact alarms would require the restricted permission.
5. **Time zone changes while the app is closed.** Alarms already queued keep their absolute instant. If the user flies to another zone, a reminder may land at an unexpected local time until the next launch re-arms.

## What to test on a real phone (5 minutes)

1. Add a subscription renewing in ~3 days, reminders ON → Controls shows `2 reminders queued` / `ACTIVE`.
2. Change the phone clock forward 2 days → both windows pass; confirm the reminder arrives (or that Controls shows nothing queued once they fire).
3. Reboot the phone → open Controls without launching any other screen; the queued count should be non-zero again (boot receiver + first-frame re-arm).
4. Turn the reminder channel off in system settings → Controls must say the channel is off and offer **TURN ON**, not `ACTIVE`.
5. Deny permission twice, then tap ALLOW → it must land on the system settings screen, not silently do nothing.
6. Tap a reminder from a killed app → it must open that subscription's detail screen, not the dashboard.
