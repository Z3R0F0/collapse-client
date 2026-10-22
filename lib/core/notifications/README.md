# Optional native push

`ENABLE_PUSH` defaults to false. Chat transport, offline history and attachments
work without Firebase configuration. No permission prompt appears on startup.

The app owns one `PushService(gateway)`. Call `initialize(onOpenTopic: ...)`
once, queue the initial topic until authentication/navigation are ready, call
`synchronize()` whenever the auth repository becomes online, call `enable()`
only from the notifications setting, and call `logout()` **before** auth logout.
Always finish local logout even if a remote token-removal request fails.

To enable, create a new collapse Firebase project and register the actual
`app.collapse.collapse` applications. Add its own Android `google-services.json`
and iOS `GoogleService-Info.plist` through FlutterFire's normal configuration.
The Android Google services plugin is activated only when that file exists.
Add the iOS plist to the Runner target, select your own Apple team, enable Push
Notifications, and upload a new APNs key to Firebase. No previous application's
identities, service accounts, APNs bridge or signing configuration are reused.
Default Firebase AppDelegate swizzling remains enabled.

Enable the stock Tinode FCM handler with that project's service account. Both
`android.enabled` and `apns.enabled` must be true for native notification payloads;
set the corresponding notification body to `$content` and a suitable title.
Use the exact fields from the pinned server's `server/push/fcm/README.md` and
config structs rather than the obsolete fork's push format. Keep service-account
keys server-side. Build the client with `--dart-define=ENABLE_PUSH=true` only
after the native configuration exists.

The native Firebase SDK presents background/terminated notifications. Foreground
chat updates remain ordinary Tinode WebSocket events; iOS also allows native
foreground presentation. There is no second background database writer, custom
APNs channel, or duplicated local-notification message implementation. Notification
taps use only standard `topic` / `xfrom` identifiers.

The unmodified Tinode v0.25.3 FCM payload does **not** include sender avatars or
image URLs. Avatar-rich push is therefore not implemented by this baseline.
Android's native FCM renderer can display a server-supplied notification image;
iOS would additionally need a notification service extension. Neither an image
enrichment service nor speculative extension is installed here. Plain native
notification text and tap routing remain supported once configured.

Web push requires separate Firebase web options, VAPID configuration and a service
worker; it is intentionally not enabled by this mobile push service. No hosted
Firebase projects were changed. Real permission, APNs/FCM delivery, app-terminated
notifications and push avatars were not tested: new credentials and physical
devices are required before those features can be claimed operational.

Official references:

- https://firebase.google.com/docs/cloud-messaging/flutter/get-started
- https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages
- https://github.com/tinode/chat/blob/v0.25.3/server/push/fcm/README.md
