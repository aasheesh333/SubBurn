# SubBurn — OneSignal setup

**Status: configured.** App ID
`060140bf-e174-4f44-85d2-f5757dfdbd35` is baked into
`RemoteConfigService` defaults, and `main.dart` initialises the SDK after the
first frame. Remote Config key `onesignal_app_id` (or
`--dart-define=ONESIGNAL_APP_ID`) overrides it without a release.

The only remaining step on the OneSignal side is linking the FCM credentials
(step 2 below) so Android push can actually be delivered — the SDK initialises
and registers the device either way, but messages need the Firebase service
account.

<details>
<summary>Original manual steps (for reference)</summary>

## 1. Create the app

1. Open <https://dashboard.onesignal.com/signup> and sign in.
2. **New App / Create App** → name it `SubBurn`.
3. Choose **Google Android (FCM)** as the platform.

## 2. Point it at Firebase

The Firebase project already exists: **`subburn-1b744`** (Spark plan), with the
Android app `com.subburn.subburn` registered.

1. In the Firebase console → ⚙️ **Project settings** → **Service accounts** →
   **Generate new private key**. Keep the JSON local; never commit it.
2. In OneSignal → **Push → Google Android (FCM)** → paste the service-account
   JSON (`project_id`, `client_email`, `private_key`).
3. Save. OneSignal stores the credentials server-side; nothing enters this repo.

## 3. Copy the App ID into the app

OneSignal → **Settings → Keys & IDs → OneSignal App ID**.

Either paste it into Firebase Remote Config (no rebuild, no release):

| Key | Value |
|---|---|
| `onesignal_app_id` | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |

or pass it at build time:

```bash
flutter build appbundle \
  --dart-define=ONESIGNAL_APP_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

`main.dart` calls `OneSignalService.initialize(...)` with the Remote Config value
and falls back to the define. With neither set, the SDK is skipped with a debug
log and the app behaves normally.

</details>

## 4. Verify

```bash
cd flutter
flutter run
```

Then in OneSignal → **Messages → New Push → Send test message**, and check the
device. The install is identified by a random `inst_…` id, never an email.

## What is already done in code

- `onesignal_flutter` in `pubspec.yaml`.
- `lib/services/onesignal_service.dart` — init, `login(installId)`, permission
  request, opt-in/out. Every call is wrapped so a failing SDK cannot block boot.
- `main.dart` — initialises after the first frame via `unawaited`, so push is
  never on the startup critical path.
- Install id is generated once and persisted in Hive settings.
- Privacy copy in **Controls → Privacy** states push is broadcast-only.

## Do not commit

`flutter/android/app/google-services.json` **is** committed — it is client-side
config and its API key is public by design (browser/Android keys are restricted
by package name and SHA-1, not kept secret).

The **service-account JSON** from step 2 must stay out of the repo. `.gitignore`
blocks `*firebase-adminsdk*.json`, `*service-account*.json` and
`serviceAccountKey.json`.
