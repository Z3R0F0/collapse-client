# Collapse client setup

A plain Tinode messenger for iPhone, Android and web. Three tabs: Chats, Contacts,
Profile; peer profiles and ordinary private/group chats. No inherited brand assets,
scenario engine, bots, purchases, custom authentication backend or product keys.

The recognizable core remains: GetIt composition, Cubits, repositories, Drift,
optimistic messages and Tinode. Flyer Chat supplies the composer and message
widgets; `flutter_list_view` owns indexed list layout and position retention.
Native pickers, recording, playback and media caching use existing packages.
The companion backend adds an independent indexed media query to pinned Tinode;
stock servers still handle ordinary chat but cannot supply the online atlas.
See [ARCHITECTURE.md](ARCHITECTURE.md) for boundaries and protocol decisions.

Clone [collapse-backend](https://github.com/Z3R0F0/collapse-backend) alongside
[collapse-client](https://github.com/Z3R0F0/collapse-client), then start with
[START_HERE.md](START_HERE.md).
It starts a clean environment without existing accounts, sessions or chat data.
For continuing development, read [HANDOFF.md](HANDOFF.md) and [AGENTS.md](AGENTS.md).

## Run with the companion backend

Use Flutter **3.41.3** (Dart 3.11.1), pinned in `.fvmrc`. With FVM, run
`fvm install` in the client directory before the commands below.

```sh
cd ../collapse-backend
node scripts/setup.mjs
sh scripts/native.sh
```

In another terminal:

```sh
cd ../collapse-client
(cd packages/tinode && fvm dart pub get)
fvm flutter pub get
fvm flutter build web --profile --no-web-resources-cdn --dart-define-from-file=../collapse-backend/.local/client.json
cd ../collapse-backend
node scripts/web.mjs
```

Open `http://127.0.0.1:8085`. Caddy serves the web build and proxies `/v0/` to
Tinode on the same origin, including authenticated media and WebSockets. The
configured backend address remains the account/cache identity; only the web
transport uses the page origin. A standalone Flutter web development server
does not provide this proxy. The local build uses optimized profile mode;
distributed release builds require TLS rather than this loopback HTTP setup.
The command bundles renderer resources instead of fetching them from a CDN.

For native development, use `fvm flutter run -d <device-id>` with the same
`--dart-define-from-file` argument from the client directory. Android
Emulator reaches the host at `10.0.2.2`: make an ignored local copy of the config
with that `TINODE_HOST`, keeping the same application key. Backend defaults bind
only to loopback. A physical phone requires an explicitly configured development
network or a TLS endpoint; it cannot reach this server through its own localhost.

Create two accounts and search for the second username in Contacts. Basic Tinode
usernames are 4-32 characters, passwords at least 8. Authentication is username /
password plus securely stored renewable tokens. No Google/Apple identities or
password-recovery provider are configured. A different server is a separate
account/cache namespace.

## Messaging

- [Telegram-style Markdown composition](MARKDOWN.md) (bold, italic, strike,
  revealable spoilers, code, links, quotes and lists),
  canonical Drafty formatting received from compatible clients, photos,
  files, video, recorded voice, image stickers, replies, forwards and deletion.
- Attachment bytes and optimistic messages are persisted before sending; failed
  sends can be retried. Local messages merge with server ACKs/echoes.
  Tinode's top-level `extra.attachments` retains uploaded files and profile
  avatars against server garbage collection. Queued attachments can be
  viewed/played from their saved bytes before upload.
  Incoming plain strings remain literal; Markdown image syntax is shown as a
  readable reference, not silently downloaded as a new attachment.
- Chat previews, receive/read counters and history are stored in Drift. One
  stable attachment per topic/session supplies previews; read/presence updates
  do not repeatedly subscribe and leave. Opening a screen is not a read receipt:
  visible incoming messages in an active chat advance the cumulative read marker.
- History pages in both directions: 40 rows per page, at most 120 in the visible
  window, retaining the scroll anchor. Older rows remain in SQLite. Live arrivals
  do not displace the history being read; the latest-messages action returns live.
- Current-chat cached text/prefix search in English/Russian, including pending
  messages. Partial history is labelled; each explicit load fetches up to 40 more
  sequences. Results are snapshots (Refresh reruns the query), with stable-ID
  navigation even after a pending message receives its server sequence.
- Terminal-like light/dark/system themes, local IBM Plex Mono labels, standard
  interactive states and English/Russian localization. Conversation text remains
  sans-serif; arrival/status effects are bounded and respect reduced motion.
- Conversation-profile media atlas: photos/video, audio and files, independently
  paginated from server history. Hero viewer with mobile zoom/swipe dismissal,
  desktop keyboard/arrows/zoom, downloads and stable selection on page loads.
  Cached atlas metadata works offline; originals must already be cached or local.

The attachment limit is 10 MiB; voice recording stops after one minute. Media
uses a bounded, account-scoped cache. Cached history is available offline, not
history or media never downloaded. Profile edits/discovery require a connection;
queued offline **messages and uploads** survive app restarts.

## Linked adaptive workspace

Chats, contacts and your profile have separate retained sections. The same
conversation stays mounted when resizing between a narrow screen and desktop:
drafts, the history window and message-list position do not depend on pane width.
Drag the left divider to resize the list or collapse it to avatars. On wide
screens, conversation info and search open beside the chat; on narrow screens
they cover it. Hidden panes cannot mark messages read or keep media playing.

Links use `/chats/:topic`, `/contacts/:id` and `/profile`. Conversation links
support `/info`, `/search?q=...` and `?message=:seq`; a valid internal destination
survives sign-in. Cached conversations open from SQLite before background Tinode
reconciliation. Uncached content still requires a connection. Native OS link
associations and push-provider delivery need separate deployment configuration.

## Verify and regenerate

```sh
fvm flutter analyze
fvm flutter test
cd packages/tinode
fvm dart analyze
fvm dart test
cd ../..
COLLAPSE_INTEGRATION_CONFIG=../collapse-backend/.local/client.json fvm flutter test test/local_server_integration_test.dart
fvm flutter test integration_test/app_smoke_test.dart -d <simulator-id> --dart-define-from-file=../collapse-backend/.local/client.json
```

The server test is opt-in and restricted to the isolated local endpoint. It
creates and deletes only its own fixture accounts. Run the native UI test on a
fresh test installation: it intentionally refuses an existing signed-in user.

After changing Drift declarations or translations, regenerate rather than edit
generated files:

```sh
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter gen-l10n
```

Web SQLite artifacts and regeneration are documented in [web/ASSETS.md](web/ASSETS.md).
Serve web builds over HTTPS or localhost; secure storage requires a secure browser
context. This is a JavaScript web build, not a Flutter `--wasm` build.

## Distribution and explicit limits

This is a local development baseline, not a signed store release. Release builds
require `TINODE_TLS=true`; configure your own TLS server, app identifiers, Apple
team and Android signing key before distribution. Nothing here reuses the old
app's Firebase files, signing keys, accounts or database. `.local/` is ignored.

Native push has an optional standard Firebase integration but is disabled until
**new collapse** provider credentials are configured on both client and server.
See [push setup](lib/core/notifications/README.md). APNs/FCM delivery on physical
devices has not been verified. Stock Tinode's push payload has no avatar; rich
avatar notifications and web push are not implemented by this baseline. Calls,
bot/scenario message entities, a Markdown editor and automatic link previews
are not included.

Tinode does not offer client publish idempotency. Lost acknowledgements are
reconciled against history before retry, but exactly-once delivery cannot be
guaranteed across every server/network failure. Deleting a queued message cancels
remaining retries and hides it locally; an already in-flight send may still reach
the server. This is not a remote recall. Local SQLite is account-isolated, not
encrypted; logout removes the token but retains cached history on this device.
There is no end-to-end encryption. Stock Tinode file refs are shareable by other
authenticated users who know the opaque URL, not protected by per-chat ACLs.

See [VERIFICATION.md](VERIFICATION.md) for actual checks and remaining device gates.
