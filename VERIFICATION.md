# Verification record

## Android push preflight and local checks: 2026-10-12

An external Android push checklist expected OneSignal integration; Collapse uses
direct Firebase Messaging and Tinode device registration. Its applicability
to this project was still unresolved when this record was written.
No notification was sent.

Executed with pinned Flutter 3.41.3 / Dart 3.11.1:

- `fvm dart pub get --enforce-lockfile` in `packages/tinode`: PASS.
- `fvm flutter pub get --enforce-lockfile` in the client root: PASS.
- `fvm flutter test --no-pub --concurrency=2 --reporter expanded
  test/push_service_test.dart test/app_router_test.dart
  test/app_navigation_test.dart`: **16 PASS**, exit 0. These cover topic parsing,
  disabled-push behavior, router/auth redirects and conversation navigation.
  They do not exercise an enabled Firebase SDK, device delivery or OneSignal.
- `adb devices -l`: no connected Android device/emulator.
- `android/app/google-services.json`: absent. Push remains disabled by default
  unless the build supplies `ENABLE_PUSH=true`; no native build was made.
- No OneSignal tools were exposed in this session. A plugin-catalog search for
  OneSignal returned no matches; provider health/configuration and subscription
  identity could not be checked through that connection.

Requested scenario status (all device scenarios **NOT RUN**):

| Scenarios | Preconditions / applicability |
| --- | --- |
| 1, 4: background and locked-screen delivery without data | Need the target app, a test Android device and configured provider access. |
| 2, 3: background/terminated tap to chat | Same prerequisites. The requested `data.type`/`data.chat_id` payload does not identify a Collapse topic. Collapse accepts `data.topic` or `data.xfrom`, validated as `usr`/`grp`/`chn` identifiers. |
| 5: foreground current-chat suppression | No device result. Collapse has no Android foreground push banner handler or active-chat suppression policy for this scenario. |
| 6, 7: foreground banners and banner navigation | Collapse does not implement the requested push banners. |
| 8: delivery after logout, then login and chat | The assumed retained OneSignal subscription does not apply: Collapse unregisters and deletes its FCM token at logout. |

Additional static finding, **not reproduced on a device**: in a process that
stays alive after logout, an already delivered notification's tap can be lost.
`HomeScreen.initState` installs the `PushService` callback with a `mounted` guard
(`lib/src/presentation/app/home_screen.dart:61`); logout disposes that screen.
`PushService._open` immediately invokes the callback without retaining a pending
destination (`lib/core/notifications/push_service.dart:83`). A later login
replaces the callback but does not replay the consumed event. The passing router
deep-link test does not cover this Firebase callback lifecycle.

Application code and provider configuration were not edited. No full test suite,
analyzer, APK build, live backend test or device acceptance was run in this check.
Historical build-118 results from another application are not current verification evidence.

## Clean source handoff: 2026-09-25

Independently extracted the source ZIP into a new temporary directory, without
the original `.git`, `.local`, database, credentials or build output. Installed
both package roots using pinned Flutter 3.41.3 / Dart 3.11.1 and
`pub get --offline --enforce-lockfile` from the local package cache.

- `flutter analyze`: clean; `flutter test --no-pub --concurrency=2`: 543 PASS,
  1 opt-in live-server integration skip.
- `packages/tinode`: `dart analyze` clean; `dart test`: 106 PASS.
- All backend `.mjs` syntax checks and `sh -n scripts/native.sh`: PASS.
- ZIP integrity, every manifest hash, exact working-tree contents, executable
  permissions and exclusion of private paths/current configured secrets: PASS.
- Independent extract -> `git init` in both repositories without commits ->
  repackage: PASS; all source bytes retained and unborn Git HEAD recorded as null.
- No fresh dependency download, backend runtime, browser or native build/device
  test was repeated for packaging. Existing running services/data were untouched.
  Only handoff documentation changed after these source tests.

See `HANDOFF.md` / `START_HERE.md` for continuation and setup. Historical `.local`
evidence paths below are intentionally not part of the clean source archive.

## Media atlas, viewer and bubble regions: 2026-09-22

Scope: client media presentation/repository, additive Drift schema 3 and the
companion Tinode/PostgreSQL metadata-query overlay. Existing auth, outbox,
message-window ownership and account data are preserved. No native project IDs,
signing, push configuration or original source repositories were changed.

- Baseline full Flutter gate: 519 PASS, 1 opt-in server-test skip, 58s
  (`.local/media-all-tests.log`). Full analyzer clean (`.local/media-analyze.log`).
- Full source gate after review, Hero, accessibility and video metadata fixes:
  538 PASS, 1 opt-in skip, 61s (`.local/media-final-tests.log`); analyzer clean
  (`.local/media-final-analyze.log`). After the final narrow MIME/unknown-duration
  correction, the focused metadata, playback, composer and pending-attachment
  suite is 39 PASS; the final full analyzer is clean
  (`.local/media-publish-analyze.log`). The full suite was not repeated after
  this last correction.
- Tinode Dart package: analyzer clean, 106 PASS (`.local/media-package-*.log`).
- Explicit live-server repository integration plus initial new cursor regression:
  15 PASS (`.local/media-integration.log`), including uploads, offline delivery,
  receipts and bounded message history on the patched backend.
- Focused real-Drift gallery tests cover metadata/history/receipt isolation,
  inline exact-message fetch, quoted/hidden entities, stable ACK identity,
  account-generation rollback, keyset cursors and v2 migration. The migration
  index assertion caught a real missing index, verified RED then GREEN.
- Viewer tests exercise desktop keyboard, mobile pinch/horizontal/vertical
  gesture arbitration, delayed Hero image, same-State retention during prepend,
  ACK/deletion cursor reporting, bounded edge requests, video lifecycle/retry,
  saving and confirmed inline audio/files. A root-router test preserves the same
  chat Cubit, draft and message window across opening, external cursor URL and
  resizing; the underlying workspace is inactive until close.
- Actual Navigator reverse-Hero flights are asserted at mobile/desktop widths:
  a real overlay shuttle interpolates back to the unchanged thumbnail rect.
  Playback activity is disabled on close without disabling the selected Hero.
  Native toolbar pointer tests measure painted-image growth/reset and contrast;
  atlas semantics has exactly one label/action per tile. The dark viewer also
  owns a route-local light system-status-bar annotation, not a global setting.
- Independent integration review found and fixed partial-cache neighbour
  selection, locally hidden URL anchors and a backfill/logout transaction gap.
  Post-review focused repository/Cubit/router/inline suite: 24 PASS.
- Eleven video-metadata regressions cover portrait dimensions/duration, canonical
  picker/outbox data, session replacement, invalid codecs/sizes, three-second
  timeout, late source/creation and slow disposal. The temporary controller never
  plays. Independent review caught the pinned player's create-error lifecycle
  observer leak; its standard metadata-only option avoids registering that
  observer, leaving existing playback defaults unchanged. Platform creation itself
  is not cancellable; cleanup must not delay attachment enqueue.
- Real Chrome checks cover a 34-item, three-category atlas outside the loaded
  chat tail, actual audio/video playback and pause, five first-click zoom/reset
  cycles, mobile touch arbitration, offline cached viewing, reply/forward bubbles
  and exact chat draft/row restoration. JS/protocol errors: 0. Evidence:
  `.local/gallery-repro-gallery16-clean/`. A cold direct media URL also passed
  in `.local/gallery-repro-gallery13-probe/`.
- The apparent first-zoom regression was traced to the diagnostic screenshot:
  clipped `captureBeyondViewport:true` emitted resize events and recreated the
  decoded gesture subtree. Full-frame RGBA crops and safe viewport captures agree;
  the clean first-click gate passes without JS interception or Debugger. No
  production click/focus workaround was introduced.
- Real picker upload exposed `mime`'s shared EBML signature being reported as
  `audio/weba`, rejected by the browser decoder. A narrow normalizer now uses only
  recognized container extensions for that ambiguous signature, including legacy
  playback; other header priorities are unchanged. Unknown video duration is 0.
  Unit/widget regressions passed, but the subsequent WebM browser acceptance was
  explicitly deferred by the user to publish the otherwise verified release.
- Backend build and 3 Go tests PASS. Isolated PostgreSQL/Tinode acceptance covers
  unauthorized/revoked access, category and before/after/around cursors, original
  entity keys, soft/hard deletions, snapshots, metadata-only output, bounded
  thumbnails and SQL index usage. Existing-message index installation preserves
  source content hashes. Details: companion `MEDIA_API.md` and README.
- Local backend deployment used a verified private pg_dump before restart.
  Configuration and existing record counts were unchanged; three additive
  indexes were installed. System PostgreSQL and the live web proxy were untouched.
- Final profile JavaScript web build: PASS, 36.7s
  (`.local/media-publish-web-build.log`). Published at
  `http://127.0.0.1:8085/chats`; served/candidate SHA-256 matches:
  `c73eb0d1e4e82087f57128c873b6bd12b6adc69dd0925103e84d4e7bfaf4e3a6`.
  Client routes and both Drift web assets return successfully. The previous build
  is retained at `.local/web-before-media-20260922`; user account/message data was
  not reset. The temporary 8086 proxy and isolated test browsers are stopped.

Offline atlas metadata does not imply an uncached original is available. Web
originals use the existing bounded session-memory cache; native originals use
the existing disk cache. Docker and physical iOS/Android devices are not verified
by these checks. No commits or source archives were created for this change.

## Adaptive navigation and message footer layout: 2026-09-22

Scope: `collapse-client` presentation only. No backend, protocol, persistence,
dependencies, generated files, platform settings or pagination changes.
Changed sources: `lib/src/presentation/app/home_screen.dart` and, under
`lib/src/presentation/chat/`, `chat_view.dart`, `chat_bubble.dart`,
`drafty_content.dart`, `drafty_text.dart`, `message_layout.dart`,
`message_header.dart`, `message_footer.dart`. New regressions:
`test/app_navigation_test.dart`, `test/message_layout_test.dart`,
`test/message_bubble_test.dart`; architecture notes are in `ARCHITECTURE.md`.

The mobile Chats tab now opens the canonical list even after a desktop chat was
retained in its branch. Reselecting a section opens its root; resize alone keeps
the same route, ChatCubit, message window and composer draft. Direct contact ->
chat -> Back retains its intended return destination.

The actual rendered Drafty paragraph determines whether time/status fit beside
its final line. Otherwise the footer gets a bottom-right row. Reply/forward
headers are inside the bubble; attachment footers remain below their content.
The implementation does not remeasure a plain-text approximation or alter list
scroll, animation ownership, message delivery or text wrapping to reserve space.

- Navigation regression reproduced RED before the fix; focused navigation,
  route and workspace suite: 24 PASS.
- New exact-geometry tests: 9 PASS (fractional fit boundary, full/short final
  line, trailing newline, taller footer, headers and actual WidgetSpan bounds).
- New real Drafty bubble tests: 12 PASS (formatting/emoji/bidi, LTR/RTL at text
  scales 1/2/3, reply action, forward header, media and stable spoiler/status).
- Combined layout/bubble/Drafty/spoiler/status tests: 39 PASS
  (`.local/bubble-focused.log`).
- Full Flutter suite: 472 PASS, 1 opt-in integration skip, 52s
  (`.local/bubble-all-tests.log`). `flutter analyze --no-pub`: clean
  (`.local/bubble-final-analyze.log`).
- Profile JS web build: PASS, 35.6s (`.local/bubble-web-build.log`). Existing
  WASM dry-run/unused Cupertino font warnings are unchanged.
- Independent source review: no material blockers; real paragraph geometry,
  paint/hit-test/semantics offsets and the actual list constraints were checked.
- Real Chrome navigation RED -> GREEN: desktop chat -> Profile -> narrow
  viewport -> Chats opens `/chats`; reopen from the list -> app Back returns to
  that list. Browser history was checked separately; no navigation trap or
  JavaScript errors (`.local/router-repro-narrow-fixed/`).
- Real Chrome bubble acceptance: 18 cases at 1280/390 widths, 14 unchanged row
  geometries through Sent -> Delivered -> Read, nine Markdown submissions,
  stable hidden/revealed spoilers, reply -> target -> Latest, and preserved
  draft/latest row through 1280 -> 900 -> 390 -> 1280. JS/protocol errors: 0.
  Screenshots were visually inspected (`.local/bubble-repro-bubble1/`). Chrome
  merges text/footer semantics, so these browser checks measure whole rows;
  exact glyph/footer non-overlap is asserted by the RenderParagraph widget tests.
- Accepted build published at `http://127.0.0.1:8085/chats`; served and candidate
  `main.dart.js` SHA-256 match:
  `1f5be800d97ab296ece8dec75d6df9d21a7e5ffb3e907d689146887574efed12`.
  Previous frontend retained at `.local/web-before-bubble-20260922`. The server,
  live proxy and user profiles/data were not restarted or reset. Isolated browser
  fixtures were removed after acceptance.

No iOS/Android binary or physical-device checks were run for this presentation
change; the full native widget suite is not a substitute for that device matrix.

## Project rename and clean source distribution: 2026-09-22

The two working trees are now `collapse-client` and `collapse-backend`.
The rename covers package/import names, Dart identifiers, asset and Kotlin paths,
native application IDs (`app.collapse.collapse`), web metadata, EN/RU app names,
storage namespaces, tooling and documentation. Generated localization/package
metadata were regenerated, not manually rewritten. No dependency versions or
Tinode protocol fields were changed by the rename.

At the user's request this is a clean baseline: no legacy session/database
import code and no existing accounts, messages, credentials or database in the
source archive. Ordinary authentication and offline persistence remain intact.
The local running server was preserved separately; its private data/backups are
excluded from distribution. `START_HERE.md` describes fresh setup.

- Final `flutter analyze --no-pub`: clean (`.local/rename-clean-analyze.log`).
- Final Flutter suite: 448 PASS, 1 opt-in integration skip, 52s
  (`.local/rename-clean-tests.log`).
- Tinode package analyzer: clean; package tests: 96 PASS
  (`.local/rename-package-analyze.log`, `.local/rename-package-tests.log`).
- Explicit real-server repository integration: 5 PASS
  (`.local/rename-integration.log`). Backend protocol smoke: PASS.
- Final profile JS web build: PASS, 36.5s (`.local/rename-clean-web-build.log`).
  Existing WASM dry-run and unused Cupertino font warnings are unchanged;
  this distribution uses the tested JavaScript web build, not `--wasm`.
- Final real Chrome fresh-profile acceptance: PASS. Title `collapse`, UI login,
  22 ordered peer deliveries without duplicates (20 rapid sends in 550ms),
  immediate composer clear, Shift+Enter newline and empty Enter no-op. Logout
  and reload stay on `/login` with no saved session keys. JS/protocol errors: 0.
  Test accounts and the isolated Chrome were cleaned up. Evidence:
  `.local/enter-repro-clean-final/report.json` and
  `.local/enter-repro-clean-final.log` (private test artifacts, not distributed).
  Accepted `main.dart.js` SHA-256:
  `bdb7db7e6cb5c6c27009dea97489adfb652906cbb4fc0ebc78f1f892fa07a991`.
- `flutter build ios --config-only --no-codesign --debug --no-pub`: PASS,
  including CocoaPods configuration. New bundle ID verified; device family
  remains `1` (iPhone only). Plists/project syntax validated. This is not an
  iOS binary, simulator run or signed store build; Android was not rebuilt.
- Independent source/archive-input review: no material blockers. Backend
  fresh setup checked with independent generated credentials. Docker is absent,
  so its runtime was not executed.
- Old-name search over maintained source/configuration: no matches;
  `git diff --check`: clean. Historical private build/test backups and Git
  history are intentionally not rewritten and are not included in the archive.
- Clean source-copy verification: dependency resolution and `flutter analyze`
  PASS (`.local/archive-analyze.log`). Quickstart includes the separate local
  package `dart pub get`, required for analyzing its own tests in a clean checkout.
  Distribution uses current working-tree files, including uncommitted sources,
  plus standard Android bootstrap files. ZIP integrity, per-file SHA-256 and
  absence of the live server's credential values are checked before handoff.

## Web Enter / Shift+Enter: 2026-09-22

One runtime change in `chat_composer.dart`: use the existing Composer setting
`sendOnEnter: kIsWeb`. Web Enter sends; Shift+Enter inserts a newline. Native
behaviour, `inputClearMode.never`, captured send intents and the outbox are unchanged.
Two focused regressions were added in `test/rapid_composer_test.dart`; the web
binding is noted in `MARKDOWN.md`.

- Targeted rapid-composer + chat-screen tests: 53 PASS
  (`.local/composer-enter-tests.log`).
- `flutter analyze --no-pub`: clean; `git diff --check`: clean.
- Profile web build: PASS, 37.5s (`.local/composer-enter-web-build.log`).
- Real Chrome RED on the previous build: Enter left `Enter actual send\n` in
  the field instead of sending (`.local/enter-repro-enter-red/`).
- Real Chrome GREEN: Enter sends and clears synchronously; Shift+Enter leaves
  the message unsent and inserts a newline, retained as Drafty BR after send;
  empty Enter publishes nothing. Twenty rapid Enter sends reached the actual
  peer exactly once each, in order. JS/protocol errors: 0
  (`.local/enter-repro-enter-fixed/`).

No backend/schema/dependency/platform configuration changes; no native build or
full-suite rerun for this isolated web binding. Prior native behaviour is covered
by the targeted tests. Accepted web main.dart.js SHA-256:
`1a16703481e34e889ec2c3d8493c34c0f3c075fce84376ca2f153d20fa640240`.
Published build replaces only local `8085` frontend files; previous build is
retained at `.local/web-before-enter-20260922`.

## Telegram-style Markdown and Drafty spoilers: 2026-09-22

Scope: extracted `collapse-client` only. No Tinode server, schema, routing,
pagination, delivery ownership, dependencies or native configuration changed.
The original source worktree and unrelated changes are untouched. The exact
supported dialect and compatibility limits are in [MARKDOWN.md](MARKDOWN.md).

- `flutter gen-l10n`: PASS (EN/RU reveal action).
- `flutter analyze --no-pub`: clean.
- `flutter test --no-pub --concurrency=2 --timeout=30s`: 446 PASS,
  1 opt-in integration skip, 50s (`.local/markdown-tests.log`).
- Transport package `dart test --reporter expanded`: 96 PASS, including
  parser, spoiler fragments, replies, Unicode, explicit Copy and malformed
  overlapping ranges (`.local/markdown-transport-tests.log`).
- Profile JS web build, local renderer assets: PASS, 37s
  (`.local/markdown-web-build.log`). Existing WASM dry-run/unused Cupertino font
  warnings do not affect the tested JS build; no dependency upgrades were made.
- Independent pinned stock Go and JS Drafty fixture checks: PASS
  (`.local/drafty-spoiler-proof/`). Plain/push/HTML/lightweight previews do not
  expose concealed text or URLs; forwarding retains the original fragment.
  Control cases reproduced why unmasked HD or public nested LN would leak.
- Independent source audit: OK after fixing entirely hidden link labels and
  Copy's grapheme-resegmentation/overlap edge. Reveal uses unchanged layout,
  excluded semantics/pointer events and opacity, including colour emoji.

The full Flutter suite ran before the final isolated Copy hardening; the entire
transport suite and final analyzer ran after it.

Real Chrome acceptance on the unchanged Tinode server: PASS
(`.local/markdown-repro-md3/`, `.local/markdown-repro-md3.log`). Nine actual
composer submissions reached the peer exactly once with the expected Drafty
styles, links, code language and protected spoiler fragments. The real Copy
action retained exact newlines (clipboard writes intercepted only in the isolated
test browser). Hidden text/URLs/emoji were absent from accessibility and paint;
reveal moved neither its row nor its two neighbours: 0px at 1280 and 360 widths.
Receipt counts did not change on reveal; own sends did not create unread counts.
No horizontal overflow or JS/protocol errors. Test accounts were removed and the
isolated Chrome closed.

The initial browser runs exposed malformed Puppeteer numpad aliases for `*` and
`/`, not Markdown/parser errors. Engine stacks pinpointed the invalid key-location
lookup. The final run uses real US physical keys/Shift and standard Unicode text
input; exact input assertions and the zero-error gate remain unchanged. No app or
SDK workaround was added.

Published at `http://127.0.0.1:8085/chats`; the served main.dart.js SHA-256 matches
the accepted candidate:
`2d58680db38b1b04344a75c653ed5e63f04ac42670be573a669ca013f47e9ba1`.
Prior build retained at `.local/web-before-markdown-20260922`.
Tinode and the user's live proxy were not restarted.

Changed sources are the Drafty codec/Markdown adapter/new spoiler helper,
DraftyText/DraftyContent/new DraftySpoiler widget, and chat Copy action. EN/RU ARB
sources and generated localization add one reveal action. Parser/codec/widget/
search regressions and this report/README/ARCHITECTURE/MARKDOWN document the scope.

No native app build, physical-device push delivery,
Telegram app executable comparison, or syntax-highlighting verification was
performed. Compatibility is based on pinned primary source inspection, not a
claim of exact parity across differing Telegram editors.

## Linked local-first desktop workspace: 2026-09-22

This change is in the extracted `collapse-client` and companion `collapse-backend`,
not the original source worktree. The companion server changes are limited to
client-route rewrites in Caddy and their documentation; Tinode protocol and
database schema are unchanged.

The application now has one long-lived GoRouter and retained section/conversation
owners. URLs cover tabs, conversations, profiles, search and message targets.
Responsive layout changes pane geometry rather than rebuilding the conversation.
The sidebar resizes and collapses to avatars; wide info/search remains beside the
chat. Explicit pane activity gates receipts, focus, playback and recording.

Opening usable SQLite history no longer waits for network attachment/metadata.
One shared background task reconciles the tail. Its explicit completion boundary
prevents descending network packets from replacing a cached page one row at a
time. Historical navigation cancels follow intent; failed sync preserves cache.

Regression evidence includes stale cached head 20 -> server head 200, joined sync,
failed fetch/retry, hidden reads/playback, late microphone permission/start,
repeated profile/chat transitions, real Cubit/draft/window retention at 390/839/
840/1200 pixels, and independent wide-search/URL target state. Independent review
also exposed and corrected null-target Back navigation, native cross-section
return, stale target errors after sending, and nested Navigator accessibility
blocking its visible sibling pane.

The first full test run reproduced an older-page eviction followed by reconnect
replacing the historical window. The fix distinguishes an evicted stable ID from
a deleted one, retaining the existing span/session/painted-viewport guards.
Ordinary prefetch and deletion retain follow intent. Old cached-first fixtures
now wait for the explicit ready tail or pause SQLite snapshots, not a network
attachment which should no longer run before the local result. Their ACK,
deletion and account-generation assertions remain intact.

The first browser pass also caught a failure invisible to widget tests: a raw
`Semantics.linkUrl` anchor performed a full Document GET on sidebar click. The
sidebar now uses the existing `url_launcher` package's `Link` and its supplied
callback, preserving standard Router dispatch and browser modifier actions.
This avoids a custom browser listener or second navigation stack.

Browser tracing then isolated an implicit DOM blur after a tooltip closed:
the input stayed enabled and mounted, but the whole route's semantic ancestor
was reparented. Pointer-only and semantic-focus native tests passed; moving the
pointer away before clicking was a diagnostic control, not a workaround.
The cause matches [Flutter #192601](https://github.com/flutter/flutter/pull/192601):
the pinned `WidgetsApp.router` lacks an enclosing `FocusScope`. The app and
router fixture now share the standard upstream scope through `buildScope`,
without SDK changes, forced focus, or disabling tooltips. Traces are in
`.local/router-repro-focus-{red,stack,subtree,neutral}/`.
The identical physical-click scenario passes after the fix, including exact
keyboard input through tooltip dismissal (`.local/router-repro-focus-fixed/`).

The 48px resize overlay also reproduced blocked mouse/touch clicks on adjacent
buttons. Its hit bounds are now 8px on the actual boundary. Six layout tests
cover adjacent clicks, boundary dragging, keyboard/slider semantics and retained
pane state (`.local/divider-{red,final}.log`).

Responsive browser acceptance reproduced a different viewport defect: text entry
kept row 64 stable, but changing 1280 -> 390px exposed row 63 and displaced the
first whole row by 161px. `flutter_list_view` only runs keyed retention when its
delegate is invalidated, not during width-only reflow of cached predecessors.
The existing paint callback now retains one stable ID/offset; width changes pass
it to the package's standard indexed layout initialization. No imperative scroll
correction, data navigation or new paging implementation was added. The exact
64 -> 63 failure is reproduced in `message_list_resize_test.dart`; its fix passes
six width round-trips, a held drag's next delta and live-tail bottom retention,
all without pagination. Browser RED evidence: `.local/router-repro-linked11/`.

The browser history gate found that reloading a search URL briefly routed through
login, replacing its old history entry and adding the search again. Back then
looped through login. CDP navigation history proved the sequence in
`.local/router-repro-history-red/`. Router mounting now waits only for local
session restoration (the cached account becomes usable before network reconnect).
Actual sign-in/sign-out route refreshes replace their entry through the standard
`Router.neglect`. The native restoring-state regression passes with the requested
URL intact and exactly one conversation owner after the local account is ready.

Current-source static/automated gates: clean `flutter analyze --no-pub`, 438
client tests passed with one opt-in server test skipped, 76 transport tests, and
eight explicit local Tinode/outbox checks passed. The final JavaScript profile
build with bundled renderer resources passed in 34.6 seconds. Logs are in
`.local/workspace-{analyze,tests,transport-tests,integration,web-build}.log`.
Real Chrome history gate (`.local/router-repro-history-fixed/`) passes: sign-in
leaves no login entry, reload preserves URL entries/currentIndex, and Back from
search returns to its conversation. The full combined flow
(`.local/router-repro-linked15/`) also passes with no unexpected browser/protocol
errors: chat/profile cycles, browser Back/Forward, narrow versus wide read
receipts, contacts search, search query/reload/target, server/local message links,
group creation/member profiles and logout/Back protection.

Width 390/900/1280 retains the painted historical key and exact draft; desktop
round-trip geometry stays within 8px, with zero subscription/history requests.
Sidebar drag collapses to avatars and restores its width. Dark, compact, mobile
and three-column layouts were visually inspected. Reload restores the draft.
A fresh conversation owner opens a SQLite-cached group offline in 376ms (including
the test's route-settle interval); all 32 sampled frames contain no welcome,
login or "Say hello" flash. A queued offline send reaches the peer exactly once
after reconnect. Sidebar links trigger zero document reloads.

Final long-history acceptance (`.local/window-repro-linked-core-final/`) passes:
3,586 samples, all 600 messages traversed in both directions, 1,703 whole-row
pixel comparisons, and zero sequence/pixel/height anomalies or unexpected errors.
All three Latest jumps reach message 600 without history requests; dwelling at
known endpoints adds none. Twenty actual rapid keyboard submissions in 619ms
arrive exactly once in FIFO order 601-620, with immediate composer clearing.

The accepted artifact is now served at `http://127.0.0.1:8085/chats`; HTTP,
`build/web` and the tested candidate have identical main JavaScript SHA-256:
`12fd9be38f28339e18b288f3534fc7ce99af15e15d298f0fde150b739c6fb4c8`.
Direct chat/profile/search/contacts/login URLs return the app; missing assets
remain 404. Only the same-origin web proxy was restarted to activate route
rewrites. Tinode stayed running (PID 12700) and user data was not reset.
The preceding build is recoverable in
`.local/web-before-linked-workspace-live-20260922/` (the earlier identical backup
is also retained in `.local/web-before-linked-workspace-20260922/`).
The post-publication Chrome smoke on 8085 passes the same sign-in/deep-link/search
reload/Back checks against real Tinode, with no unexpected errors
(`.local/router-repro-history-live/`). Test Chrome and synthetic accounts are
cleaned up; staging 8086 is stopped. The user's web 8085 and backend remain running.

Native OS universal/app-link association files and notification-provider delivery
are deployment work, not enabled by URL routing alone. Physical microphone/phone
checks and offline cold browser bootstrap are not claimed by these local tests.

Source boundaries: `lib/{main,app}.dart`, `lib/src/presentation/navigation/`, app shell/
workspace/settings/peer rows, chat screen lifecycle/navigation/recording/search/
list, chat Cubit/open/live/paging, the existing chat repository history/topic
sync/session lifecycle, `ChatChange`, and `lib/widgets/view_activity.dart`. Existing
EN/RU localization was extended and regenerated. Dependency changes are limited
to pinned `go_router: 17.1.0` and the SDK's `flutter_web_plugins`; web orientation
is adaptive. No native platform configuration or database schema was changed.
New and updated regressions are in the router/URL/workspace/activity/recording,
offline-first/cached-tail, media lifecycle, and existing history/search suites.
No commit or remote write was made for this task.

## History-independent unread counter: 2026-09-22

The previous chat counter measured incoming messages after the current window,
not unread messages. Scrolling into already-read history followed by a peer
receipt reproduced Chat=40 while Home=0 (`.local/unread-window-red.log`).

Chat now observes the same account/topic unread projection as Home. Paging and
live-window refreshes do not write the count. A generation-scoped subscription
receives local/other-session reads even during a pending history request; opening
the ready snapshot retains that count. Both old subscriptions are canceled before
yielding, so overlapping navigation cannot cancel a newer listener.

- Seven new regressions pass: old read history, both page directions/latest,
  local and remote reads, incoming versus own ACK/echo, held navigation, topic
  replacement and same-account session replacement.
- Full `flutter test --no-pub --concurrency=2 --timeout=30s`: 375 passed,
  1 opt-in server test skipped. `flutter analyze --no-pub`: no issues.
- Explicit real Tinode integration plus outbox-generation suite: 8 passed.
- Optimized JavaScript profile web build: passed, 35.2 seconds.
- Independent read-only review found no material issue. The message-list/scroll
  algorithm, schema, generated files, dependencies and backend are unchanged.
- Real Chrome with 160 Tinode messages: Home starts at 5, viewing the latest
  advances read to 160, and 55 older-history wheel steps retain Chat/Home=0.
  Two new incoming messages give Chat/Home=2; further paging and peer receipts
  leave both at 2. Another session reads 161/162: both counters become 1 then 0
  without navigation. All 63 paging samples pass; exactly four history requests
  cover initial load and three older pages, with no unexpected browser/protocol
  errors. Evidence: `.local/notice-repro-notice-fixed/` and matching `.log`.

The tested build is published at `http://127.0.0.1:8085`; actual HTTP JavaScript
SHA-256 matches the candidate:
`7631894946ca37ca38bfc2743670d31f490678430d484352993cca457880554b`.
The preceding build is retained in `.local/web-before-unread-window-20260922/`.
Synthetic accounts and Chrome were cleaned up; the temporary 8086 proxy was
stopped. The user's native backend and live web remain running.

Logs: `.local/unread-window-{red,targeted,tests,analyze,integration,web-build}.log`.
Native builds/physical devices and push providers were not rerun for this
platform-neutral counter fix.

Changed source: `lib/src/presentation/chat/{chat_cubit,chat_open,chat_live,chat_paging,chat_state,chat_view}.dart`.
New regression: `test/chat_unread_count_test.dart`; existing counter fixtures and
assertions now distinguish unread from window distance. Documentation: this record
and `ARCHITECTURE.md`. No commit or remote write.

## Own-message notices: 2026-09-22

The follow-up fixes two reproduced defects without changing the indexed list or
history-window algorithm. A lagging DB successor displayed Latest even while the
user was following the tail and could trigger another latest navigation on send.
The sequence-minus-read calculation also counted own ACKs as unread.

Latest visibility/send navigation now use follow intent. One scoped SQL count
subtracts known own positive sequences; unknown gaps and genuine incoming remain.
Both topic observers read topics and messages, so late own bodies repair the
badge. No local read watermark is advanced by sending. Browser verification also
found a visible incoming row left unread after closing search: returning to the
current route now schedules the existing guarded post-layout visibility check.

- Initial regression checks failed for the button on the first frame, an extra
  latest navigation, own unread counts, and a route-return with delayed geometry
  callbacks; the corrected implementation passes these checks.
- Full `flutter test --no-pub --concurrency=2 --timeout=30s`: 368 passed,
  1 opt-in server test skipped. `flutter analyze --no-pub`: no issues.
- Explicit real Tinode integration plus outbox-generation suite: 8 passed.
- Optimized JavaScript profile web build: passed, 35.2 seconds.
- Independent code review found no material issue. Schema, generated files,
  dependencies, backend and protocol receipt writes were not changed.
- Final real Chrome run: 250 animation-frame samples through 20 actual keyboard
  submissions in 610 ms and peer receipts; zero Latest-button appearances,
  exact FIFO delivery and an empty composer after every send. Home own-only
  unread is zero. A covered search route preserves the incoming unread; returning
  reads the visible message without another event. Reading history keeps a new
  incoming unread and shows the real Latest control (positive sampler control).
  The home badge is exactly one, then zero after actual viewing. No unexpected
  browser/protocol errors. Final evidence: `.local/composer-repro-badge-fixed3/`.

The earlier `badge-fixed` sampler accidentally started during login and matched
the home tile; its six frames are not evidence of a send-button flash. That run
did reproduce the route-return read failure. `badge-fixed2` verified the read
fix and zero flashes but attempted a history wheel during the pop transition;
the final run waits for the route and preserves all incoming/unread assertions.

The tested build is published at `http://127.0.0.1:8085`; actual HTTP JavaScript
SHA-256 matches the candidate:
`96f77dccfed820f6a179fdef9d60d1c648e04e2a3bae2c6fb665c8d004dacfae`.
The preceding build is retained in `.local/web-before-own-notice-20260922/`.
Synthetic accounts and Chrome were cleaned up; the temporary 8086 proxy was
stopped. The user's native backend and live web remain running.

Logs: `.local/own-notice-tests.log`, `.local/own-notice-integration.log`,
`.local/own-notice-web-build-final.log`. Native builds/physical devices and push
providers were not rerun for this platform-neutral follow-up.

Changed source: `lib/core/database/{app_database,topic_queries,topic_counts}.dart`,
`lib/src/data/chat/chats_repository.dart`, and
`lib/src/presentation/chat/{chat_cubit,chat_live,chat_view,chat_screen}.dart`.
Regression files: `test/{own_message_notice,own_message_unread,chat_screen,outbox_window}_test.dart`.
Documentation: this record and `ARCHITECTURE.md`. No commit or remote write.

## Corrective acceptance: 2026-09-22 (complete)

The September 21 checks below are historical. They did not prove seamless
continuous scrolling; the user's rejection reopened that acceptance.

Before changing the implementation, real Chrome reproduced reverse movement
during upward scrolling in a 600-message, varied-height conversation. The stock
latest control made a history request from the current window. Twenty immediate
keyboard submissions delivered only one message and accumulated the rest in the
composer. Baselines are preserved in `.local/window-repro/` and
`.local/composer-repro/`.

The replacement uses `flutter_list_view` 1.1.29 layout-time keyed retention;
repository coverage/spans, Cubit navigation and viewport state are separate.
Deterministic checks already passed for 120 -> 120 replacement in both directions,
held drags, ongoing flings, ACK identity, explicit index navigation, gesture retry
after a rejected page and retained follow intent during DB event lag.
Data regressions first reproduced disconnected offline islands, false endpoints,
covered-range refetches and unbounded empty scans. Additional ACK/local-cursor
regressions were reproduced before their fixes. Rapid-submit and outbox wakeup
tests likewise include failing-before/passing-after cases.

Final corrective-source checks:

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | No issues |
| `flutter test --no-pub --concurrency=2 --timeout=30s` | 356 passed; 1 opt-in real-server test skipped |
| Transport `dart analyze` / `dart test --concurrency=2` | Clean / 76 passed |
| Opt-in real-server test plus outbox-generation suite | 8 passed, including 4 local shutdown/init regressions and actual Tinode |
| Backend `node scripts/smoke.mjs` | Passed |
| `flutter build web --profile --no-pub` with local defines | Passed; JavaScript target, 34.6 s |
| Real Chrome 600-message window/pixel/rapid-send gate | Passed; details below |
| iOS Simulator debug build, no codesign, local defines | Passed; compiled `UIDeviceFamily` is `[1]` (iPhone only) |
| Android debug APK, local emulator defines | Passed; 24.6 s |
| Real Chrome media, retained uploads/avatar, search and visual gallery | Passed; final2 artifacts below |
| Published-origin smoke at `http://127.0.0.1:8085` | Passed after publication |

The real-server run additionally exposed SQLite close/reopen racing in-flight
work. Shutdown, failed-init retry and logout-before-late-ACK cases were reproduced
and fixed, then independently reviewed. Ordinary logout stays nonblocking.
The headless history test now explicitly supplies the viewport's not-following
intent; a database page boundary is not treated as a scroll event.

Historical counts do not substitute for corrective-source evidence. Local logs:
`.local/windowfix-tests.log`, `.local/windowfix-integration-final.log`,
`.local/windowfix-web-build.log`, `.local/windowfix-ios-build.log` and
`.local/windowfix-android-build.log`.

The first corrective browser run exposed a separate OPFS worker failure during
login: all 40 history packets and terminal completion arrived within 14 ms, but
the client stayed busy beyond 90 seconds. A safe request-ID-only worker trace
showed successful outer commits followed by unanswered rollbacks of those same
executors. Concurrent native-isolate tests did not reproduce the browser lock
interceptor's nested-transaction behavior. Baselines and protocol traces remain
in `.local/window-repro-fixed/`, `.local/window-repro-fixed2/` and
`.local/window-repro-dbtrace/`. Coverage updates now use their existing
message/deletion transaction, retaining a transaction wrapper for standalone
coverage writes. Four added regression tests cover single-owner coverage and
concurrent duplicate history via a real background database executor. The final
browser gates below include successful login with the shipped OPFS worker.

The next real Chrome pass (`.local/window-repro-fixed4/`) traversed all 600
varied-height messages in both directions without missing sections. Reply
600 -> 7 and three direct Latest transitions passed; those Latest actions and
known-endpoint dwell caused no history requests. Twenty keyboard submissions in
about 600 ms produced exactly 20 ordered messages, with an empty composer after
each submission. This pass is still not final smoothness acceptance: independent
pixel analysis of 1,878 wheel pairs found one extra 62 px movement, and cold-page
latency caused boundary stalls. A matching widget test reproduced the same
62 px at the same step; a separate test reproduced a 6 px first-row padding
change after prepend. Both failures were retained as gates for the next build.

Both pixel regressions are now GREEN, including an in-place same-ID message
update at the same cold scroll step. Padding is index-independent, row updates
retain the list widget, and prefetch leaves more than one viewport of runway in
both directions. A reply-highlight test checks both expiry and unchanged target
geometry/list identity. An additional history test reproduced 40 packets causing
80 merges/receipts through global and request-result paths; scoped single-flight
reduces this to 40. Failure retry and account/session separation are tested. The
356-test suite, clean analysis and 8-test real-server gate above include these
final changes. The final Chrome run adds a pixel-motion assertion, not only
sequence-coverage checks.

That final window gate passed (`.local/window-repro-fixed5/`):

- 3,586 viewport samples; 1,703 shared, fully visible, stable-height row
  comparisons against actual wheel input. No wrong-direction/extra displacement
  over the 8 px tolerance, no whole-row height changes, no missing sections.
- All 600 message sequences were observed on both complete passes. Cold and
  cached upward passes each took 482 identical wheel steps; the reverse pass
  took 481. Reversal and fast trackpad bursts also passed.
- Actual reply 600 -> 7 reached the target. Latest from reply, middle and oldest
  snapshots reached 600 without intermediate history requests. Known-endpoint
  dwell caused no requests. History remained bounded to 40 sequences per request.
- Each subsequent 40-packet history interval emitted 40 note commands, not 80.
- Twenty actual keyboard submissions within 578 ms cleared the field each time
  and produced exactly the intended 20 payloads in FIFO sequence 601..620.
- No unhandled Dart/JavaScript errors. The earlier failing artifacts are retained
  separately, not replaced with these passing results.

The following media pass exposed a further real failure, retained in
`.local/windowfix-gallery/` and `.local/windowfix-media-gc-red/`: an uploaded PNG
returned identical bytes with HTTP 200 immediately after ACK, then HTTP 404 from
both stock Tinode and the proxy after 65 seconds, before fixture cleanup. Local
pending bytes and cached incoming files had masked the remote failure.

Two verified corrections follow the stock protocol and deployment model:

- The gateway now sends managed refs in top-level `extra.attachments`, not only
  `pub.head.attachments`. Profile updates include the new/existing avatar ref.
  Wire-envelope and profile regressions failed before correction and now pass.
- Both backend runners give only Tinode/init-db `TZ=UTC`. The pinned server
  writes UTC timestamps but formed the GC cutoff in local time; pgx's
  timezone-less timestamp encoder preserves wall-clock fields. On this UTC+3
  host, an unlinked fresh file could therefore look older than the one-hour
  cutoff. No database timezone/schema/data or GC settings were changed. The
  managed native runner was restarted against its existing database, then the
  real-server integration and backend smoke passed again.

This preserves referenced uploads; files already deleted by the server cannot
be reconstructed automatically from their now-missing remote refs.

### Final media, search and visual acceptance

The completed run is `.local/windowfix-media-final2.log`, with artifacts in
`.local/windowfix-media-final2/` and 17 screenshots in
`.local/windowfix-gallery-final2/index.html`. The earlier interrupted
`.local/windowfix-media-final/` is not counted as a completed acceptance run.

- Actual image display, WAV/video decoding and playback, and file download passed.
  Fresh players after offline chat reentry used cached media without another GET.
- The actual photo picker showed an offline local preview; reconnect uploaded
  and delivered exactly one message. Independent direct-Tinode and proxy GETs
  returned the exact 1,471-byte PNG immediately, after reentry and after 65 seconds
  (one stock garbage-collection interval).
- The actual profile photo picker updated the avatar. A peer could download the
  exact avatar bytes, including after 65 seconds. Independent read-only SQL
  confirmed one message link for the sent PNG and one user link for the avatar
  before synthetic fixture cleanup; no retention settings or database data were
  modified for the check.
- EN/RU prefix search, truthful partial-cache status, explicit history completion,
  at most 40 history sequences per action and a jump outside the 120-row window
  passed. Opening the covered search route did not mark unseen messages read.
- Light/dark EN/RU screenshots cover all three tabs, profiles, chat/media,
  keyboard focus and search. Narrow 360 px captures cover auth, tabs, profiles
  and chat/media; keyboard-focus and search captures use a 1120 px desktop
  viewport. Independent visual review found no overflow, missing image/avatar
  or retry placeholder in these captures. The graphite/ash/amber terminal kit
  uses the existing theme and standard interaction states.
- No unexpected HTTP/protocol or unhandled Dart/JavaScript errors occurred.
  Deliberately induced offline connection failures are retained in the log.

### Publication and limits

The validated optimized JavaScript profile build is served at
`http://127.0.0.1:8085`. The published file and actual HTTP response match the
tested candidate's `main.dart.js` SHA-256:
`f338ed28106a9220b708f154e4e81d5055a2e72c7b58dbc96cc06def16fe1547`.
The published SQLite WASM also matches the tested candidate. The previous build
is preserved in `.local/web-before-windowfix-20260922/`.

The final published-origin run, `.local/windowfix-live-smoke.log`, passed real
registration/login, profile edit, contacts and peer profile, queued/sent/delivered/
read transitions, exact subsequent composer input, incoming messages, reload with
secure session and SQLite state, offline recovery, logout and group invitation/
membership/delivery. Test Chrome and staging port 8086 were stopped; synthetic
accounts were cleaned up. The user's backend and web at 8085 remain running.

Current-source native builds passed, but physical-device UI/background playback
and APNs/FCM provider delivery were not exercised in this corrective acceptance.
No signed store build was produced. Docker was not run; integration used the
native backend against its existing database. This local HTTP profile build does
not weaken the release TLS guard. Upstream indexed-list visited-key height
metadata may grow with visited history; loaded messages and motion state remain
bounded to 120. These checks establish the listed scenarios, not a guarantee
against every possible device or timing combination.

Only the two Collapse repositories were changed. Original source repositories and
unrelated user changes were left untouched; no commit or remote write was made.

## Historical acceptance: 2026-09-21

Date: 2026-09-21. Local macOS Apple Silicon, Flutter 3.41.3 / Dart 3.11.1,
unmodified Tinode 0.25.3 with isolated PostgreSQL 14.22.

This record distinguishes protocol/repository tests from rendered UI and device
checks. The original Flutter/backend repositories were read-only inputs. Only the
two new local repositories are deliverables; no remote repository was changed.

## Automated coverage

Final command results:

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | No issues |
| `flutter test --no-pub --concurrency=2` | 264 passed; real-server test skipped here by design |
| `dart analyze` in `packages/tinode` | No issues |
| `dart test --concurrency=2` in `packages/tinode` | 73 passed |
| Opt-in `test/local_server_integration_test.dart` | Passed against local Tinode |
| `node scripts/smoke.mjs` in backend | Passed |
| `flutter build ios --simulator --debug --no-codesign --no-pub` with local defines | Passed; compiled `UIDeviceFamily` is `[1]` |
| `flutter build apk --debug --no-pub` with local defines | Passed |
| `flutter build web --debug --no-pub` with local defines | Passed; JavaScript target |
| Native `integration_test/app_smoke_test.dart` | Passed on iOS/Android at initial extraction; not rerun for this queue |
| Drift regeneration and locale generation | Completed |

- Transport: handshake/auth, requests/errors, topic attachment deduplication,
  history completion, disconnects, upload origin/header rules and fragment-free
  browser WebSocket URLs; canonical Drafty grapheme ranges, Markdown, bounded rich
  quotes, entities, media/replies/forward and interrupted upload/liveness probes.
- Auth: token vault, restore/reconnect, invalid versus transient errors,
  single-flight login, logout/account-switch races and no repeated login on resume.
- Persistence: durable outbox/attachment bytes, stable optimistic IDs and ACK/echo
  merge, account isolation, sequence ordering, receipts, deletion and bounded pages.
- Chat widgets: initial preloaded state, variable-height 120-to-120 replacement
  in both directions, 40-to-80 older-page callback, foreground/background read
  behavior and no displacement/read of unseen live arrivals while reading history;
  existing bubbles update queued/sent/delivered/read status and uploaded media refs
  without changing message IDs or recreating the chat.
- Media/push boundary: authenticated same-origin fetch, external URL allowlists,
  data-size limits and safe ordinary Tinode notification topic parsing.
- New combined regressions: ACKs for evicted pending rows, 165-row pending tail,
  stable-ID search targets during ACK/deletion, stale receipts across account
  changes, no-op scroll completion, coalesced arrivals/ACKs, continuous-arrival
  read receipts and quiet pagination/background/reentry.
- Search: schema 1 -> 2, external-content FTS5 triggers, bounded legacy projection
  excluding media bytes, literal RU/EN prefix queries, cursor rollback after error
  and one bounded history interval per action. Shipped SQLite WASM was exercised
  in real Chrome, not inferred from native SQLite tests.
- UI: light/dark text contrast and focus/disabled/pressed states, 48dp targets,
  enlarged EN/RU auth/profile/chat/search layouts, fixed-box status transitions,
  late draft restore, enqueue failure, quick-send/disposal and conditional draft
  cleanup without overwriting a newer route or account.

The real-server Flutter test uses two accounts, profiles/avatars/discovery,
IM/AU/VD/EX uploads and downloaded bytes, replies/forwards, read/receive counters,
SQLite close/reopen with pending offline image, 200+ messages, bidirectional
windows, frozen history while live messages arrive, groups and deletion.
Its video fixture proves transfer, **not codec playback**.

## Initial extraction evidence

- Android debug APK built successfully (`build/app/outputs/flutter-apk/app-debug.apk`).
- iOS Simulator debug app built successfully (`build/ios/iphonesimulator/Runner.app`).
- JavaScript debug web build succeeded (`build/web`).
- Native integration test passed on iPhone 16 Pro / iOS 18.3 Simulator and Android
  API 36 Emulator: UI registration, real secure-storage token write/read, all three
  tabs, token reconnect/restore, logout and vault cleanup. No mocked native vault.
  Both native checks were rerun after the final browser/profile/message-status
  fixes; ordinary app-entrypoint artifacts were rebuilt afterward.
- The new iOS target is iPhone-only in Debug/Profile/Release. Both simulator and
  emulator were stopped after their checks to avoid parallel machine load.
  The final compiled iOS app's `UIDeviceFamily` contains only `1`.
- Final headless Chrome UI run passed registration, profile edit, contacts/peer
  profile, two-user send/receive and visible read receipts. The same message bubble
  changed from queued to sent, delivered and read without reentering the chat.
  Reload restored the token, SQLite preview and edited profile; offline queue
  reached sent after reconnect; logout/basic login and group creation/invitation/
  delivery passed. No unhandled Dart/JavaScript exceptions or server responses
  with a control code of 400 or higher occurred. The test intentionally induced
  one offline network diagnostic. Screenshots were visually inspected.

## Improvement queue acceptance

The automated results above apply to the improved client. The final web build
was tested at `.local/web-next` before copying it to `build/web`; JavaScript and
SQLite Wasm checksums match. The build's Wasm dry-run warnings concern Dart Wasm
compilation, not the working SQLite Wasm database in the JavaScript build.

Earlier stage gates passed real Chrome audio/video/image/file playback/download,
offline media re-entry, and actual offline file picker -> local preview -> upload
-> one observed peer delivery. A persistent old browser profile upgraded from
schema 1 to 2 with session and outbox intact. RU/EN search went from partial to
complete through <=40-sequence explicit loads and jumped to message 1 outside
the current window. A new peer message stayed unread while search covered chat;
reconnect may legitimately replay an existing read watermark.

- Final real Chrome checks passed registration, profile/contacts, two-way messages,
  sent/delivered/read transitions, reload/session restore, offline sends and groups.
  A second message typed without replacing the composer's contents reached its
  peer with the exact expected text, proving submission had cleared the old text.
- Actual WAV/WebM playback, background pause, image/file download, cached offline
  re-entry and offline photo picker -> preview -> upload -> one observed delivery
  passed. No unhandled Dart/JavaScript exceptions or unexpected error controls.
- The final search run used a fresh history longer than the 120-row window:
  RU/EN prefix queries, explicit bounded history loading, unread preservation
  under the covered route and exact old-message navigation passed.
- Seventeen screenshots in `.local/terminal-gallery/index.html` cover keyboard
  focus, light/dark EN/RU layouts, all tabs, 360px media/composer and search/jump.
  Screenshots were visually inspected; Flutter web semantics helpers required
  settled focus transitions and targeting the active editing element.
- Current-source iOS Simulator and Android debug artifacts were rebuilt after
  all changes. iOS still targets only iPhone. Earlier native UI tests are not
  represented as testing the new UI kit or physical-device media codecs.
- The validated web is served at `http://127.0.0.1:8085` through the same-origin
  Caddy proxy. The previous build is retained at
  `.local/web-before-terminal-20260921`. Tinode/PostgreSQL were not restarted;
  user data and browser profiles were not reset.
- Final live-origin smoke at 8085 passed registration, group/invitation/message,
  incoming PNG and a real outgoing photo-picker upload with a portable ref.
  Settled EN/light and RU/light/dark 360px images are in
  `.local/final-browser-gallery/index.html`; there is no media/composer clipping.
  The log is `.local/browser-final-8085.log`. The isolated Chrome process and
  temporary 8086 proxy were stopped; the user's 8085/6060/55432 services remain.
- Final read-only ownership review matched documentation to window, ACK/merge,
  generation/receipt and motion code plus combined regressions. No material
  discrepancy remained. Tinode still has no server-side publication idempotency;
  client reconciliation reduces but cannot eliminate every ambiguous-ACK duplicate.

## Independent review findings addressed

Reviews separated transport/auth, storage/windowing, backend/protocol and rendered
UI. They identified actual upstream constraints: no last-body on `me`, no history
without attachment, descending forward responses, trailing-slash upload endpoint,
GC attachment refs and no publish idempotency. Tests encode these contracts.
Rendered tests also found an incorrect scroll-anchor sign and Chrome rejecting an
explicitly empty WebSocket fragment, both corrected with regression coverage.

Further independent review led to explicit tests for first unsolicited chat and
group invitations, live metadata updates, account changes during picker/delete
operations, group author labels, inline Drafty media, streaming download limits,
and cancelling offline sends across late ACKs. Android Auto Backup is disabled
to prevent restoring encrypted preferences without their device Keystore key.
Image preview geometry remains fixed while bytes decode, preventing delayed
images from moving a restored scroll anchor. The app keeps its root focus tree
while resetting account navigation; own-profile loading waits for completed
authentication during cold session restore.
Flyer's retained rows are refreshed with its standard `updateMessage` operation;
`setMessages` is reserved for changed window membership/order. A reproduced
queued-status regression and independent review cover this adapter boundary.

## Not demonstrated by these checks

No production deployment, Docker runtime, store signing/upload, APNs/FCM delivery,
terminated-app push or physical-phone permission/camera/microphone/video playback
matrix was verified. WebAssembly compilation is not supported by the current
secure-storage dependency; the tested target is the standard JavaScript web app.
Push requires fresh external provider configuration, documented separately.
Codec support remains platform-dependent; browser playback used WAV/WebM/PNG,
not an exhaustive physical-device codec matrix. No production FPS guarantee is
inferred from debug/widget/browser tests.
