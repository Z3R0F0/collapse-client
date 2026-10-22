# Collapse client: agent guide

These instructions apply to this repository, including `packages/tinode`.
This is **Collapse**, a standalone messenger. Do not import unrelated
bot/scenario code, service locators, assets, signing or old agent instructions.

## Start here

1. Run `pwd` and `git status --short --untracked-files=all`. Clone the companion
   backend alongside this repository as described in `START_HERE.md`.
   Preserve unrelated working-tree changes.
2. Read `HANDOFF.md`, `ARCHITECTURE.md`, `SETUP.md` and the latest section of
   `VERIFICATION.md`. `WORK_PLAN.md` is historical, not a fresh backlog.
3. Locate files with `rg --files` / `rg`. Read the complete affected slice:
   widget -> Cubit -> repository -> transport/database and its tests.
4. For cross-feature work read `lib/main.dart`, `lib/app.dart`,
   `lib/dependency_injection.dart` and the affected platform integration first.
5. Check the companion `../collapse-backend/MEDIA_API.md` before protocol edits.

## Ownership and invariants

- One GetIt composition root in `lib/dependency_injection.dart`. Keep existing
  shared lifetimes and disposal order; route-scoped Cubits remain disposable.
  `packages/tinode` owns protocol/codecs, not UI, another locator or app storage.
- Repositories under `lib/src/data` own I/O. Widgets must not issue Tinode/SQL
  calls directly. Prefer small files and private Dart part extensions in the
  existing owner over new coordination services or duplicate state.
- `lib/core/database` is one account/server-scoped Drift database. Schema 3 adds
  media metadata to history/outbox/search persistence. Change schema only with
  migrations, matching query/index definitions and regenerated code.
- Persist outgoing content and attachment bytes before network work. Keep stable
  client IDs through ACK/echo merge, local-sequence cursors, short local FIFO
  writes and session-generation checks. Do not make delivery depend on a mounted
  row, a visible window or an animation. Lost ACKs do not imply exactly-once
  delivery: Tinode does not provide client publish idempotency.
- History coverage, API requests, the bounded message window, navigation intent,
  viewport position and animation state are separate owners. Pages are 40 rows;
  the visible window is at most 120 messages. Eviction never deletes SQLite rows.
  Offline unknown gaps are blocked, not exhausted.
- `flutter_list_view` owns keyed position retention. Latest/reply/search replace
  a ready window at an initial index; never scroll through intermediate pages.
  Layout changes must not trigger API paging. Keep terminal-edge, painted-row and
  request-generation guards. Arrival effects are paint-only and never replay on
  page loads or ACKs.
- Read receipts require visible incoming messages in an active app/route/pane.
  Own messages must not generate unread badges; Home and the Latest badge use
  the same database-derived count, not sequence distance.
- `MediaGalleryCubit` / `MediaGalleryRepository` own independent media cursors.
  `meta.media` must not enter normal history coverage, receipts or ChatCubit.
  Preserve original entity keys, stable pending-to-ACK identity, deletion/ACL
  invalidation and partial-offline-cache semantics.
- The single app-owned GoRouter and conversation Cubit survive width changes.
  URLs are canonical; carousel selection replaces the URL instead of pushing
  another history entry. `ViewActivity` gates retained panes and playback.
  Keep the documented Flutter 3.41 FocusScope compatibility wrapper until the
  SDK is deliberately updated and its web regressions pass.
- Canonical Drafty JSON stays on disk/wire. Preserve grapheme offsets, original
  entity indices, quote/spoiler privacy, reply/forward content and top-level
  `extra.attachments` retention links. Parse Markdown only for outgoing text.
- Use the existing Material theme, `context.collapseTheme`, `context.colors`,
  `context.textStyles`, and `context.l10n`. New strings need both
  `lib/l10n/app_en.arb` and `app_ru.arb` plus generation. Do not add a second UI kit.
- `MessageLayout` uses actual paragraph geometry, including formatted spans.
  Do not replace it with plain-string width guesses or post-frame scroll fixes.
- Reuse `MediaRepository` for authenticated, bounded downloads/cache. Keep web
  conditional imports, background pause, timeout and late-disposal guards.
  `extended_image` owns image gesture arbitration; do not layer competing gesture
  recognizers over it. Unknown codecs retain fallback delivery, not a hung send.

## Platform and safety

- Supported targets: iPhone, Android, web. No iPad or native desktop targets.
  The desktop facade is a responsive web layout. Do not change IDs/signing as
  incidental cleanup; current application ID is `app.collapse.collapse`.
- Push is optional and disabled until fresh provider credentials are configured.
  Follow `lib/core/notifications/README.md` and `ios/PLATFORM.md` /
  `android/PLATFORM.md`; do not introduce a legacy silent-push bridge.
- Web must retain `web/sqlite3.wasm` and `web/drift_worker.js`, same-origin Caddy
  `/v0/` proxying and client-route rewrites. Plain `flutter run -d chrome` is not
  the documented integrated backend setup. See `web/ASSETS.md`.
- Never log session tokens, auth headers, private payloads or credentials.
  Do not copy `.local`, databases, signing keys, Firebase files, build output or
  machine-specific paths into a source handoff.
- Use patch-based source edits. Do not manually edit
  `lib/core/database/app_database.g.dart`, `lib/l10n/app_localizations*.dart`,
  generated native registrants or other generated build files.
- Do not upgrade broad dependencies, change architectures, run destructive Git
  commands, reset data or create commits/pushes without explicit authorization.

## Verification

Use Flutter 3.41.3 / Dart 3.11.1, pinned in `.fvmrc` (prefix with `fvm` if needed).
First install dependencies in BOTH package roots:

```sh
(cd packages/tinode && dart pub get)
flutter pub get
flutter analyze
flutter test --concurrency=2
(cd packages/tinode && dart analyze && dart test)
```

Run heavy test/build/browser jobs sequentially, not concurrently. For changes,
add focused regressions and distinguish what actually ran from intended checks.

```sh
# After database / localization edits, respectively:
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n

# With a separate isolated local backend running:
COLLAPSE_INTEGRATION_CONFIG=../collapse-backend/.local/client.json flutter test test/local_server_integration_test.dart

# Integrated local web build; serve it with backend scripts/web.mjs:
flutter build web --profile --no-web-resources-cdn --dart-define-from-file=../collapse-backend/.local/client.json
```

Integration tests may create/delete only their own fixture accounts. Do not run
them against production or clear real user data. Native UI tests require a fresh
test installation; signing, physical-device push and Docker claims require their
own actual verification. WebM browser acceptance was deferred by the user; do not
silently report it as passed or reopen it as a mandatory blocker.

Finish with changed files, behavior, commands/results, checks not run and known
risks. Keep `HANDOFF.md` and architecture/protocol documents current when their
contracts change. Never claim a build/test merely because an older snapshot passed.
