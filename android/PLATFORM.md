# New collapse Android application

Application ID: `app.collapse.collapse`. Minimum Android API 24 is selected for the
recording/media plugins. Release builds do not use a debug signing key; configure
a new collapse keystore before distributing.

Android Auto Backup is disabled: encrypted session preferences must not be
restored without the device's original Keystore key. History resynchronizes
from Tinode after a fresh login.

Internet and network state are declared for all builds. Camera and microphone
are optional hardware; runtime prompts come from the image/recording plugins.
The system photo picker and Storage Access Framework handle selected media/files,
so broad storage and library-read permissions are intentionally not requested.
Notifications require the Android 13+ runtime permission, requested only from
the notification setting.

Only the Debug manifest enables a network-security configuration which permits
cleartext for localhost, `127.0.0.1`, and Android Emulator's `10.0.2.2` host alias.
Other origins and Release/Profile use HTTPS/WSS. A physical device needs its own
intentionally configured reachable endpoint. Do not weaken the release policy
to connect to a development server.

Firebase is optional until a new project's `app/google-services.json` is present
and the Dart `ENABLE_PUSH` flag is set. See `lib/core/notifications/README.md`.
