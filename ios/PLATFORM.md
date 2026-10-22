# New collapse iOS application

iPhone only (`TARGETED_DEVICE_FAMILY = 1`) in Debug, Profile and Release.
iPad is not a native target of this new application.

The app uses Flutter's standard AppDelegate and Firebase's default swizzling.
There is no old silent-push method channel or inherited Apple team. Minimum iOS
15.0 is required by the locked Firebase SDK. Physical-device signing requires
your own team/profile and the Push Notifications capability.

Only Debug uses `Runner/Info-Debug.plist`, which permits HTTP for `localhost` and
`127.0.0.1` for local development. Release/Profile use `Runner/Info.plist` with no
ATS exception: configure a real HTTPS/WSS backend before shipping. Keep the
permission descriptions and ordinary bundle metadata in the two plist files in
sync. A physical device requires an intentionally configured LAN/TLS endpoint,
not the simulator's loopback address.

Camera, photo-library and microphone prompts occur through the corresponding
media plugins when the user selects those actions. App background modes support
fetch and remote notifications; they do not make background network delivery
guaranteed. See `lib/core/notifications/README.md` for required new Firebase/APNs
configuration and the explicit limitations of plain upstream notifications.
