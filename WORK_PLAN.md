# Collapse improvement queue

Historical implementation log. For the current handoff and verification limits,
start with [HANDOFF.md](HANDOFF.md); older counts below are not the latest results
and completed stages are not a new backlog.

## Complete: linked, local-first adaptive workspace (2026-09-22)

Implemented and independently reviewed; final analysis and 438 client tests pass
(one opt-in test skipped), with 76 transport and eight explicit Tinode/outbox
checks. Actual Chrome acceptance covers URLs/auth/history, retained responsive
panes/drafts/anchors, sidebar collapse/drag, receipts and offline queue delivery.
The 600-message/rapid20 gate passes 1,703 pixel comparisons without anomalies.
Browser acceptance additionally reproduced and fixed a Flutter Router focus-scope
omission, divider hit interception, width-reflow anchor drift and auth/history
pollution on reload. The accepted artifact is published on 8085; the previous
build is retained and Tinode/user data stayed intact. See VERIFICATION.md for
evidence and native deep-link/provider/physical-device limits.

1. Replace imperative feature-page pushes with one long-lived `go_router`.
   Canonical URLs own the section, topic, detail panel and explicit message target;
   auth preserves a safe internal destination. No chat/profile stack cycles.
2. Return usable SQLite snapshots before network work. Track bounded background
   reconciliation with existing session/disposal guards; do not show the empty
   conversation invitation before the initial local read has completed.
3. Keep branch navigators and the selected conversation mounted across responsive
   layout changes. A retained master/detail workspace owns only pane geometry,
   including a draggable, persisted sidebar that collapses to avatar width.
   Explicit pane activity gates focus, receipts, animations and media playback.
4. Use a retained conversation shell for optional info/search panels. Mobile
   replaces the visible pane; wide screens show the panel beside the same chat.
   Data window, viewport, draft, route and pane width remain separate state.
5. Verify URL reload/back/forward/auth, repeated profile/chat navigation, live
   resize with drafts/history, hidden-pane receipts/media, cache-only offline
   opening and offline sends. Run independent review, full analysis/tests and
   real browser acceptance before publishing on 8085. Preserve the prior build.

Work sequentially through the following stages. Preserve the existing GetIt,
Cubit, repository, Drift and standard Tinode boundaries. Keep the user's running
backend and web session available while preparing and testing new builds.

1. **Code organization** - split overloaded files by responsibility; use private
   Dart parts/extensions, preserve public class methods and clear naming. Verify
   unchanged behavior, schema and generated code.
2. **Offline, resume and media** - interrupted uploads/publishes, pending queue
   after restart, account changes, background/resume, bounded downloads/cache,
   audio/video/image/file behavior on native and web. Reproduce faults in tests
   before fixing; no custom replacement of existing storage or player packages.
3. **Markdown and Drafty** - standard Markdown parser, canonical Drafty payloads,
   supported message types and readable message composition/rendering. Preserve
   protocol compatibility, replies, forwards and media references. Verify local
   queued media previews as well as remote and inline media; display must not
   require an upload to finish or alter the durable wire payload.
4. **Conversation interaction** - send/receive animations independent of history
   loading; stable viewport while reading older messages; efficient reply jump.
5. **Message search** - clarify scope; use the existing database and standard
   Tinode history API, with explicit completeness/progress and bounded work.
6. **Terminal-like UI kit** - coherent minimalist, dystopian visual language for
   all elements. Restrained palette, terminal details, legible conversation text,
   focus/hover/pressed/loading/error states, purposeful short motion, accessible
   reduced-motion support. Use the existing theme rather than a parallel system.
7. **Final acceptance** - independent review, analysis and automated tests,
   client/backend integration, actual browser media/UI checks, applicable native
   checks, then publish the validated web build. Record remaining limits honestly.

No feature or aesthetic work in a later stage should delay verification of the
current stage. Run heavy checks sequentially. Do not change unrelated source
repositories, reset user data, push remotes or make unrequested commits.

## Reopened: continuous sliding-window pagination (2026-09-22)

Status: corrective implementation, independent review and publication complete.
The following problem statement is retained as the acceptance baseline.

The previous acceptance did not establish seamless continuous scrolling. The
user reproduced jumps, skipped sections, repeated boundary pagination and a
latest button that scrolls the current window instead of replacing it. The
earlier test counts remain historical evidence, not proof that this works.

Confirmed original causes:

- Flyer and the screen both restore scroll position after pagination; Flyer's
  own restoration also assumes an increased item count, not 120 -> 120 eviction.
- The built-in bottom button drives pixels and enables newer-page loading.
- Normal history queries ignore stored coverage and can join disconnected cache
  islands; offline end flags confuse unavailable history with exhausted history.

Corrective acceptance must use a real long, varied-height conversation and
continuous wheel/drag gestures in both directions, including direction reversals,
opposite-edge eviction, every known boundary, direct latest/reply navigation,
offline gaps, late ACK/live arrivals and delayed fetches. Record visible message
IDs/positions and actual request ranges, not just final screenshots. A single
established list mechanism must own viewport preservation; API/cache coverage,
window membership, navigation intent and animation state remain distinct.

Additional reopened items from the same review:

- Rapid text entry/immediate submission: real Chrome reproduced only one delivered
  message from twenty submissions, with submitted text accumulating in the input.
  Revisit synchronous composer handoff, local enqueue ordering, draft ownership
  and outbox wakeups independently of network/navigation/render completion.
- Visual direction: the current Material styling does not meet the requested
  dystopian, minimalist, terminal-based living interface. After correctness gates,
  build and inspect a coherent chat-screen prototype, then apply the validated
  direction across the existing UI kit; keep accessibility and restrained motion.

Implementation is gated on the state/ownership analysis and an isolated ready-made
list spike. The user requested autonomous completion, not intermediate approval.

### Corrective implementation and gates

The state analysis and indexed-list spike are complete. A single keyed list now
owns layout; explicit navigation swaps a ready snapshot. Coverage, local-origin
membership, terminal/offline edges and viewport eviction leases have independent
regression tests. Composer handoff is synchronous; local writes are FIFO and an
active outbox drain cannot miss a newly queued send.

Real browser acceptance exposed additional OPFS transaction nesting, duplicate
history-store work and cold sliver rebuild/padding defects. These were reproduced
before correction. The exact 62 px scroll defect and same-ID content variant now
pass, as do fixed padding, two-direction prefetch and independent reply highlight.
The terminal kit uses graphite/ash, restrained amber, mono labels and one small
generated identity mark across platforms, with no new theme framework.

Final current-source gates: 356 client tests, 76 transport tests, clean analysis,
8 local-server/outbox integration checks, optimized profile web, Android debug
and iPhone-only simulator builds passed. The 600-message real-browser gate passed with 1,703
pixel comparisons and exact rapid20 delivery. Media acceptance additionally
exposed missing Tinode `extra.attachments` and a host-local GC cutoff; standard
attachment envelopes and UTC backend launch correct these, including avatars.
Final retained-media, avatar, offline picker/playback, search and 17-frame gallery
checks passed, including exact remote bytes after a garbage-collection interval
and independent database-link/visual review. The validated build is published at
8085; the final live-origin core smoke passed and the previous build is retained.
Test Chrome and staging 8086 are stopped; the user's web and backend stay running.
Stages 4, 6 and 7 reopened below are now closed by this corrective acceptance.
See VERIFICATION.md for final evidence and physical-device/provider limits rather
than relying on historical stage counts.

## Window, outbox and motion invariants

The database owns delivery, the Cubit owns the bounded history window, and the
view owns motion/scroll. Leaving the visible window must never cancel delivery
or erase a pending message. A stable client ID survives acknowledgement and
sequence changes. Acknowledgements update the existing bubble; history loads,
reconnect backfill and duplicate events must not replay entry animations.
Incoming messages must not move the viewport while reading older history.
Motion bookkeeping must remain bounded and respect reduced-motion settings.

Verify combined scenarios, not just each mechanism separately:

- Queue offline, leave/evict the message from the 120-message window, reconnect,
  then merge the acknowledgement exactly once without moving historical views.
- Receive while reading history; page both ways without repeated animations.
- Reconnect with duplicate events and late acknowledgements across sessions.
- Jump to a reply target outside the window, then return to the live edge.
- Background during upload/playback, resume, and retry without duplicate sends,
  stale loading states or unexpected playback.

Conversation-motion acceptance must also verify that restoring an anchor and
returning to the live edge updates the actual follow-live policy; a suppressed
scroll callback during restoration must not leave the Cubit following history
while the viewport is already at the bottom.

## Progress

- Stage 1: complete. Client analysis and 77 tests, transport analysis and 23
  tests, Drift regeneration and real-server integration passed. Schema and
  generated database output are unchanged.
- Stage 2: complete. Fixed reproduced outbox/session races, bounded media waits,
  web cache limits and player lifecycle/late async actions with regression tests.
  Outbox/session, transport liveness/upload abort, cache and player tests pass.
  Pending-tail traversal passes for 165 queued messages and a mixed server/local
  history with a 120-row window. Open/page races with ACK/deletion and stale
  successor flags have deterministic regressions. Full client analysis and 133
  tests, 40 transport tests and real-server integration passed. Actual Chrome
  registration/groups, audio/video/image/file download and offline chat re-entry
  passed; images were visually inspected. Browser media required same-origin
  Caddy because stock Tinode's file GET omits cross-origin response headers.
  Final incremental pending-tail eviction regression is fixed; 25 focused tests
  and scoped analysis passed after the full suite.
- Stage 3: complete. Markdown uses the maintained Dart parser; Drafty follows
  official Tinode 0.25.x grapheme offsets and QQ quotes (legacy QR remains
  readable). Full client analysis and 155 tests, 57 package tests, plus 3 DB and
  5 package preview regressions passed. Drift regeneration left the schema and
  generated database unchanged. Real-server Markdown/reply/media/outbox/history
  integration passed (one initial Flutter test-listener socket startup failure
  required a retry, before application code ran). Actual Chrome media suite and
  offline photo picker -> local preview -> reconnect -> single delivery passed;
  queued photo and offline playback screenshots were visually inspected.
- Stage 4: reopened on September 22; previous checks follow. Arrival/update/history provenance and bounded one-shot
  paint-only motion are independent of delivery/window state. Combined tests
  cover coalesced ACKs/arrivals, eviction/reentry, background, continuous arrival
  receipts, reply/page invalidation and 120-to-120 anchors. Reproduced no-op
  observer scroll hangs are avoided without a replacement scroll mechanism.
  Rich reply excerpts are bounded without changing originals or forwarding.
  Full client analysis and 186 tests, 73 package tests, real-server integration,
  web debug build and actual Chrome media/offline-picker suite passed. No-op
  scroll and short-list receipt regressions went from failing to passing.
- Stage 5: complete. Standard SQLite FTS5 searches cached text, with independent
  bounded result pages and explicit history completeness/loading. Client analysis,
  217 tests plus two late-draft regressions, real-server integration and web build
  passed. Native and shipped WASM FTS probes passed. Actual Chrome schema 1 -> 2
  migration preserved session/cache/offline queue; EN/RU search, one <=40-message
  fetch per action and outside-window exact-ID navigation passed. A new message
  remained unread under search (reconnect may replay the existing read watermark).
- Stage 6: reopened on September 22; previous checks follow. Standard Material states, neutral light/dark
  palette and locally bundled mono labels; no parallel UI/state framework.
  Theme contrast/targets, EN/RU large-text auth/profile/chat/search layouts and
  fixed-geometry status motion have regression tests. Draft submission now keeps
  failed/newer text, uses conditional cleanup after disposal and guards session
  changes; initial restore does not re-save stale values.
  Independent acceptance audit additionally reproduced and fixed evicted pending
  ACK admission into a pure pending tail and stale receipt emissions after
  account changes/relogin. Three window and four receipt regressions went
  RED -> GREEN; adjacent 22-test and 31-test batches and scoped analysis passed.
- Stage 7: reopened on September 22; previous checks follow. Client analysis and 264 tests,
  package analysis and 73 tests, opt-in real Tinode integration and backend smoke
  passed. Real Chrome media/offline/search and EN/RU light/dark gallery passed;
  current-source iOS Simulator and Android debug builds passed. The validated web
  is published at 8085 through Caddy; the old build is recoverably retained.
  Live-origin registration/group/message/image-picker smoke and settled EN/RU
  light/dark 360px media screenshots passed without unhandled exceptions.
  Independent final ownership review found no material documentation/code
  mismatch. Temporary Chrome and staging proxy were stopped; user services stay
  running. See VERIFICATION.md for artifacts and physical-device/provider limits.
