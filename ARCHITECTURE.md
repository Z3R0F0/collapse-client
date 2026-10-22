# Collapse

A plain Tinode messenger. This extraction deliberately keeps the former app's
layering, not its product-specific features or assets.

## Boundaries

`Widgets -> Cubits -> repositories -> Tinode transport / Drift`

- One GetIt composition root. Shared transport, repositories and database;
  one disposable chat Cubit per conversation route, not per responsive pane.
  No locator inside the transport package.
- Pinned upstream Tinode with a small PostgreSQL media-query overlay; ordinary
  auth, messaging, uploads and renewable tokens keep the stock protocol.
  Authentication never starts gameplay or implicitly requests permissions.
- Canonical Drafty JSON is the wire/storage representation. Flyer Chat supplies
  the composer and bubble infrastructure; `flutter_list_view` owns list layout.
- One durable database, account/server-scoped data, transactional ACK/echo merge,
  raw outbox content and pending attachment bytes retained across restarts.
- A 120-message in-memory window, 40-message pages, older AND newer loading,
  opposite-edge eviction and layout-time keyed position retention. Eviction never
  deletes persistent history. History requests use completion packets, not sleeps.
- `me` supplies sequence/read/receive counters. Stock Tinode does not supply the
  last message body there, and forbids unattached history requests. Stable topic
  attachments supply bodies; incoming presence/read events must not cycle them.
- Read receipts are driven by visible messages while the app is active, not by
  arrival of database rows. Background receipt and displayed-read are distinct.
- English/Russian strings use Flutter's generated localization. Material theme
  tokens and a small ThemeExtension replace brand assets and the oversized kit.

There are no scenario commands, bot services, game effects, purchases or inherited
production identifiers, credentials, account databases or media assets.

## File organization

Entry-point classes retain their public methods, lifecycle and owned state.
Private Dart `part` extensions group implementations by responsibility: history,
outbox delivery, realtime events, receipts, scrolling and media. They do not add
new service instances or expose extension methods as replacement public APIs.
Independent models and widgets have named files; existing entry points re-export
extracted public types to preserve imports. Database tables and query groups are
separate parts of one Drift database; generated files remain generator-owned.

## Delivery, window and media

Delivery lives in the account-scoped outbox, never in a row widget or a history
page. The stable client ID survives ACK/echo merge and sequence changes. Pending
rows have their own local-sequence cursor and remain traversable across the
server-history boundary. Page commits and realtime updates share a short Cubit
queue; network requests stay outside it. A page re-reads its explicit span from
one SQLite transaction before committing, including fresh rows, ACKs and
deletions. Retained local-origin rows keep their local position through ACK;
their new server sequence does not silently change the history cursor. A bounded
set of retained local IDs defines optimistic membership; `localSeq` is only the
paging cursor. A delayed ACK outside the server span therefore stays visible,
while an actually evicted ID cannot reappear through an overlapping cursor.
Only locally persisted optimistic identities establish local origin, never a
peer's wire `localSeq`. An ACK for an evicted row is not a new live arrival.

Local send/draft writes have a short FIFO tail. Each send captures its immutable
payload and session before waiting, then commits message, attachments, outbox and
conditional draft cleanup together. Enqueue completion never waits for the
network or navigation. Enqueue during a running outbox drain marks it dirty;
the drain checks again immediately instead of waiting for a retry timer.

Session generations invalidate old uploads/retries across logout or account-session
replacement. Ordinary reconnect resumes the same durable queue. A
late accepted ACK may still reconcile its original account, but cannot publish
new work or change the new session's UI. A standard Tinode probe checks apparently
open sockets on resume. None of this depends on whether a bubble is mounted.
Receipt synchronization checks both account scope and session generation after
asynchronous work, immediately before emitting on the authenticated socket. An
old account's completed database write must not acknowledge a new account's chat.
Logout does not wait for network workers. Their settlement remains owned until
repository disposal, which drains old ACK/event/local-write work and crosses a
standard Drift exclusive barrier before its caller closes SQLite. A failed local
session initialization rolls back its matching generation so retry can initialize
the same account normally.

Web uses the companion Caddy proxy for same-origin `/v0/` HTTP and WebSockets;
the configured Tinode endpoint remains the durable account/cache identity.
Uploads store portable relative refs. Authentication is sent only to the exact
trusted media origin; redirects are rejected. Downloads have bounded waits and
size, and the stock cache manager uses a bounded, session-only web memory cache.
Playback pauses when backgrounded or covered and never resumes automatically.
Managed upload references are also sent through the standard top-level
`extra.attachments` envelope for publishes and avatar metadata updates;
`head.attachments` alone does not establish the server's retention links.
The companion Tinode process runs in UTC, matching its PostgreSQL timestamp
storage and avoiding a host-local garbage-collection cutoff. Neither server
schema nor garbage collection is replaced or disabled.

### Independent media atlas and viewer

`MediaGalleryCubit -> MediaGalleryRepository -> gateway.media / MediaEntries`
owns media selection and keyset cursors independently of `ChatCubit`, message
coverage, list window and scroll. The server's attached-topic reader ACL guards
`get.what=media`; correlated `meta.media` pages emit no `data` or receipts.
Three additive PostgreSQL partial indexes query existing messages by category
and `(seq, original entity key)`, including history the client has never opened.
Current soft/hard deletions apply to each page. A captured sequence ceiling keeps
older pagination stable; refresh/newer queries can include later arrivals.
See the companion backend's `MEDIA_API.md` for protocol and deployment limits.

Drift schema 3 adds an account-scoped metadata-only table/index, not duplicate
chat rows or inline originals. Existing local messages are indexed in small
batches; ordinary enqueue/ACK/receive/delete transactions keep metadata aligned.
ACK keeps the stable client/entity identity. Late session responses roll back
their cache write. Offline browsing is explicitly partial; uncached originals
still require connectivity. Inline-only media fetches at most its exact message
when opened, never the intervening history. New photos include known dimensions
and a bounded standard Drafty thumbnail before the durable outbox commit.
New videos read dimensions/duration through the existing local video player,
without playback, under a three-second metadata deadline. Decode failures keep
ordinary attachment delivery available; late platform initialization cannot
delay enqueue or bypass the existing session-generation guard.

The conversation profile uses a lazy categorized sliver grid. Its root viewer
route leaves chat/profile state mounted but inactive, preserving draft, window
and scroll. Desktop gets navigation/zoom controls and keyboard shortcuts;
mobile gets gallery swipes, pinch/double-tap zoom and vertical dismissal.
Pinned `extended_image` owns gesture arbitration and Hero slide behavior; the
existing `MediaRepository` remains the sole authenticated byte/cache owner.
Prepending pages atomically replaces the stock PageView at the selected index,
with stable nearby image keys preserving zoom. No after-frame corrective jump.
Video pauses when its page, route or app loses activity. Saving is retained.

Reply headers render a compact quote instead of replaying quoted attachments;
the body keeps original entity indices. Forward headers and media bubbles use
the existing theme. Known media dimensions determine tight, bounded geometry;
unknown dimensions keep a stable fallback rather than moving the list on decode.

## Window, motion and navigation

### Linked adaptive workspace

One application-owned `GoRouter` (17.1.0, compatible with the pinned Flutter SDK)
owns URLs and three retained section branches. It is not recreated by connection,
theme or window-size changes. Authentication preserves only validated internal
destinations; logout removes the authenticated workspace and its subscriptions.
There is no independent selected-tab/selected-topic navigation Cubit.
The Router widget mounts after local session restoration, not after network
reconnection. Sign-in/sign-out refreshes replace the current URL using the
standard `Router.neglect`; a transient login must not become a Back destination.

| URL | Destination |
| --- | --- |
| `/chats` | Conversation list / desktop selection placeholder |
| `/chats/:topic` | Conversation |
| `/chats/:topic?message=:seq` | Explicit server-message navigation |
| `/chats/:topic?local=:id` | This account/device's locally queued message |
| `/chats/:topic/info` | Conversation profile; `member` selects a group member |
| `/chats/:topic/search?q=:query` | Cached-message search |
| `/chats/:topic/media?seq=:seq&entity=:key&kind=:category` | Media viewer |
| `/chats/:topic/info/media?seq=:seq&entity=:key&kind=:category` | Viewer opened from the profile atlas |
| `/contacts`, `/contacts/:id` | Contacts and contact profile |
| `/profile` | Own profile/preferences |

Route state contains identifiers and intent, not profile objects, Cubits or tokens.
Queued media uses `pending=:clientId` instead of `seq`; the URL follows its ACK
and carousel selection with replacement, not a new history entry per image.
Titles come from repository streams. Notification opens use the same chat URL
builder. Native universal/app-link association files and push-provider setup are
separate deployment concerns. The web uses Flutter's path URL strategy; Caddy
rewrites only client-owned paths, leaving `/v0/` and static assets unchanged.

Feature navigation replaces the declaratively matched page stack; it does not
push another arbitrary chat on top of a profile. A small serializable return hint
lets explicit web Back traverse Flutter's standard browser `UrlStrategy` history
instead of appending a new URL. Direct links without that hint use the canonical
parent. Search input replaces its query entry rather than creating one entry
per keystroke. URLs remain sufficient to construct every destination without
the hint or an already-mounted parent.
Sidebar rows use the existing `url_launcher` package's standard `Link`, including
internal Router dispatch and browser modifier clicks. A raw semantic href is not
enough: Chrome would reload the whole document. Section links and direct URLs use
canonical-parent app Back; browser Back/Forward keep their normal history. The
return hint applies to explicit in-app transitions such as profile -> Start chat.
An explicit mobile Chats-tab selection opens `/chats`, not a retained desktop
conversation with its old return hint. Reselecting the current section also opens
its canonical root. Switching desktop sections still restores their selection;
resizing alone never navigates, recreates a ChatCubit or clears a draft/window.
`AppRouter.buildScope` supplies Flutter's standard enclosing `FocusScope` to
`MaterialApp.router`. The pinned SDK omits it: showing/dismissing an OverlayPortal
tooltip can reparent browser semantics and blur an input. This small compatibility
wrapper follows [Flutter's upstream fix](https://github.com/flutter/flutter/pull/192601)
and can be removed when that fix reaches the pinned SDK; it does not force focus
or disable tooltips/accessibility.

`WorkspaceLayout` only owns geometry: at 840 logical pixels the master list sits
beside the same branch Navigator. A 72-pixel avatar strip or 240-420-pixel list
width is persisted through `SettingsCubit`; mobile never overwrites that choice.
The divider supports pointer drag, focus, arrow/Home/End keys and slider semantics.
Its 8-pixel hit area stays on the pane boundary, leaving neighbouring controls
clickable; the explicit collapse/expand button also works without dragging.
The master/detail slots remain in the same widget-tree positions, with finite
nonzero constraints even while offstage. Resizing cannot create/close a chat.
The message viewport retains one painted stable ID and its local offset. Width
changes reflow cached row heights, so the existing indexed-list delegate receives
that checkpoint through `initIndex/initOffset` during layout (or its usual bottom
alignment when following live). This changes neither the Cubit's navigation epoch
nor window membership and does not scroll through pages or issue network work.

The conversation shell similarly retains its ChatCubit, screen, composer and list
while info/search change panes. At 860 pixels of detail space a 360-pixel panel
fits beside the chat; otherwise the panel covers it. Stable identity depends on
account/topic, not width, message-query or panel selection. Message query changes
are navigation intents handled by the existing ready-snapshot mechanism.
Info/search URLs can carry the same message target. Wide-screen search selection
keeps the results panel mounted while replacing the chat's ready window; clearing
a target does not close an open panel.

`ViewActivity` combines parent/branch/pane visibility and gates focus, semantics
and tickers. Chat receipts/arrival effects and attachment playback additionally
combine it with modal-route and application visibility. An inactive retained
branch is not "read" merely because its nested Navigator still considers its
chat route current; playback pauses and never auto-resumes on return.
Hiding a recording conversation or backgrounding cancels its microphone capture,
including an in-flight start, without sending it. A first-use permission dialog
does not itself cancel the pending request; already queued messages remain owned
by the outbox, independently of pane visibility.

### History ownership

An open first inspects the existing coverage-aware SQLite snapshot. A usable
cached tail or exact cached target returns before network attachment, metadata,
deletions or history fetching. One shared topic/session task reconciles in the
background; opening and account refresh join it instead of duplicating work.
Explicit started/completed/failed history-sync events distinguish an incomplete
descending server page from its ready snapshot. A chat still following latest
can replace an obsolete cached tail only after completion; user navigation or
scrolling cancels that follow intent. Failures leave the rendered cache usable.
This uses the same repository/window/list ownership, not a second cache or list.

| Owner | State / responsibility |
| --- | --- |
| Tinode + Drift repository | Covered server ranges, local-origin rows, atomic snapshots, bounded network fetches |
| `HistoryWindow` | Server/local cursors, bounded retained local IDs, `available` / `exhausted` / `blocked` edges |
| `ChatCubit` | Current bounded window, request generation, explicit navigation epoch/target, follow intent |
| `MessageList` | Painted keys, gesture direction, layout position and index initialization |
| Screen motion | Short-lived arrival timestamps and reply highlight; no delivery or pagination state |

Offline cache islands are not joined across unknown ranges. `blocked` means a
missing interval is unavailable offline, not that history has ended. Coverage
includes deleted ranges, so an empty page can advance a span without inventing
rows. Each pagination action fetches at most one missing <=40-sequence interval;
covered data is reused. Reconnect re-evaluates edge availability.
An accepted older page that actually evicts the followed tail cancels follow
intent. A missing tail ID is checked against storage to distinguish eviction from
deletion; ordinary prefetch and deletion do not cancel follow. The existing
painted-row lease and span/session guards still decide whether a page may commit.
Message/deletion writes update coverage inside their existing transaction;
standalone coverage writes open their own. They do not nest transaction scopes,
avoiding the pinned OPFS worker lock-completion failure reproduced in Chrome.
The global data stream and a completed history request can contain the same
immutable Tinode sequence. They join one in-flight store per account/session,
topic and sequence before the completed-sequence cache takes over. Only its
owner merges the row, emits the change and records receipt; failure releases the
entry for retry. This does not combine separate ACK, deletion or receipt flows.

`flutter_list_view` 1.1.29 owns position retention by stable client ID during
layout (`keepPosition` and sliver scroll-offset correction). Replacing 120 rows
with 120 rows does not invoke `jumpTo`, cancel a fling, or rely on total scroll
extent differences. User scroll notifications request pages; layout/metric
changes cannot request one. A late page which would evict the last painted
viewport is cached but not committed. Painted IDs are an eviction guard, not
pixel offsets or a database cursor.

List identity depends on ordered message IDs and explicit positioning, not on a
loading flag or a delivery icon. A bounded immutable row snapshot feeds ordinary
`ValueListenableBuilder`s, so body/status/highlight updates do not rebuild the
sliver. The same widget instance is retained following Flutter's
[build-cost guidance](https://docs.flutter.dev/perf/best-practices#control-build-cost).
Row padding is explicit and does not change when index zero becomes an interior
row. Directional prefetch begins within two viewport heights of an available
edge; it remains one bounded page at a time and cannot run from layout updates.

After offline ACKs interleave with peer messages, explicit pagination may
normalize the local order into server order. This cache-only rebase selects a
fresh bounded snapshot around the first painted stable ID, without changing the
navigation epoch. Its commit is rejected if that first painted ID changed during
the request. The list preserves that key's geometry and suppresses tail/resize
auto-placement for the rebase frame only. Ordinary pages retain every painted ID;
they do not use the rebase exception.

Latest/reply/search opens a ready snapshot with a new navigation epoch and
initial index. The old snapshot stays visible while loading; there is no walk
through intermediate pages. Latest controls overlay the viewport rather than
changing its height. Cached row widgets are disabled in the list package;
message/motion state is bounded. Upstream's visited-key height metadata is not
bounded to 120 entries; no claim of a strict 120-entry total metadata cap is made.

The repository classifies changes as arrival, history or update before serial
event processing. Known server rows and local ACK/echo matches are updates.
The Cubit emits arrival IDs only for new rows admitted at the followed live edge;
these IDs are not copied into later pagination, loading or receipt states.
When uncorrelated live data overlaps a history request for the same topic, effects
are conservatively suppressed; delivery and message storage are unaffected.

The screen captures these one-shot IDs before coalescing snapshots. Its bounded
timestamp map belongs to the current window, not the outbox. A 180ms paint-only
fade/translation cannot change row height or anchor geometry. ACKs retain the
same client-ID key, widget and entry age; evicted/reloaded rows do not reanimate.
Background, covered routes and reduced motion suppress entry effects. Receipts
skip only still-entering rows, never all reads during a continuous message burst.

History mutations use Flyer's nonanimated controller updates with retained-row
updates first, then expose rows and navigation epoch together to `MessageList`.
The screen has no second anchoring mechanism. Group padding is fixed rather than
animated when neighbors change at a window edge. Jump highlighting is separate
from arrival effects. Sending from history starts a quiet latest navigation after
local commit, without delaying the next send.

The Latest overlay and send-from-history navigation use follow intent, not the
database's newer-edge availability: rapid writes may precede their window events.
The Latest badge uses the same DB-derived topic unread count as Home, not a
distance from the window's end. A generation-scoped topic subscription updates
it independently of history loading, including read presence from another
session. Paging/navigation never recompute or clear unread; ready snapshots
preserve count changes received while loading. The SQL count excludes known own
server sequences, and topic watchers observe messages as well as topics so a
late own body corrects it. Unknown cache gaps remain conservatively incoming;
own ACKs never advance the local read watermark or read earlier incoming.
Returning to the current chat route schedules the same guarded post-layout
visibility check; cached rows need not emit another visibility-detector callback.

## Drafty

Only outgoing composer text is parsed as Markdown, using the maintained Dart
`markdown` package. Its AST is converted directly to canonical Drafty; there is
no second stored representation, HTML renderer or automatic Markdown image fetch.
The UI reads structured content without copying attachment payloads through JSON.
Malformed format ranges are ignored without reindexing entity keys.

The [formatting contract](MARKDOWN.md) uses Telegram's double-delimiter core,
retaining existing GFM syntax as explicit Collapse extensions. Tiny custom
syntaxes extend the maintained parser; there is no second regex parser.
Spoilers use HD with a nested Drafty fragment in `data.spoiler` and a masked
outer `txt`. Nested link URLs stay inside the fragment too, because upstream
plain/push previews expand public LN targets. Stock lightweight previews omit
this extension. CO entities optionally retain code-block language metadata.
Only explicit Copy restores spoiler text; previews/search/reply excerpts remain
concealed. UI reveal owns no database, network or viewport state and changes
opacity/semantics, not the message's layout footprint.

`MessageLayout` composes the header, actual Drafty paragraph and delivery footer
in one layout pass. It uses Flutter's laid-out
[`RenderParagraph` selection boxes](https://api.flutter.dev/flutter/rendering/RenderParagraph/getBoxesForSelection.html),
including shaped bidi runs and actual WidgetSpan bounds, to check the footer's
vertical band. A fitting footer shares the final line; otherwise it gets its own
bottom-right row. Earlier text lines never lose width to a reserved status column.
There is no second plain-text measurement, duplicate hidden footer or post-frame
size correction. Reply/forward headers participate in bubble width; media uses a
separate footer row. Width is capped by the conversation pane, not the browser.
The layout owns no message identity, animation, receipt or pagination state.

Tinode 0.25 clients use grapheme-cluster offsets and `QQ` quotes. This follows
the [pinned JavaScript implementation](https://github.com/tinode/tinode-js/blob/v0.25.1/src/drafty.js)
and [server implementation](https://github.com/tinode/chat/blob/v0.25.3/server/drafty/drafty.go),
whose behavior supersedes the older code-point wording in the Drafty document.
The UI also reads the former `QR` quote alias. Already stored untagged, incorrect
code-point ranges cannot be reliably distinguished from valid grapheme ranges;
their text is retained, but ambiguous old styling is not automatically rewritten.

Reply excerpts remove nested quotes/hidden text and retain up to 256 graphemes,
styles, links, media refs and small inline previews (up to 4 KiB each). The quote
JSON is capped at 16 KiB; exceptional oversized excerpts become readable text
and media filenames, not broken attachment widgets. The original, forwarding
and the new reply body remain unchanged. This prevents recursive quote growth
from eventually exceeding the server message limit.

## Message search

Search is scoped to the current chat's cached message text. Standard SQLite
FTS5 `unicode61` provides case-insensitive Russian/English word and prefix
matching, not arbitrary substring matching or language stemming. Hidden text,
nested quotes and attachment payloads are excluded from the derived body.

Schema 2 adds a rebuildable text table and external-content FTS5 index with
standard synchronization triggers. Existing messages/outbox rows are not
rewritten. Legacy cache preparation uses 40-row keyset batches; normal message
writes, ACK merges and deletions update the derived index transactionally.
Result snippets and result pages are bounded, independent of the chat window.

The search Cubit owns debounce, query cancellation and a result cursor stack,
not message delivery or conversation pagination. Results are query snapshots;
Refresh reruns the query. Selecting a result resolves its stable client ID,
including queued messages outside the visible window. An unavailable target
keeps the prior conversation context and refreshes retained IDs from SQLite.

The UI distinguishes index preparation and partially downloaded history.
Loading more history fetches only one missing interval of up to 40 sequences
through the existing Tinode API; it never marks messages read or downloads the
whole conversation implicitly. Coverage includes known deletion intervals.

## Terminal UI

One Material theme owns graphite/ash surfaces, sparse amber signals, thin outlines
and 6dp corners. Primary actions use neutral inverse surfaces, not accent-filled
pills. Bundled [IBM Plex Mono](assets/fonts/README.md) is used for headings,
labels and code; ordinary conversation text stays 16sp sans-serif. No runtime
font service, bitmap decoration, custom control framework or second theme system.
Controls retain Material focus/hover/pressed/disabled/error states and padded
48dp targets. Auth forms, profile preferences and search wrap on narrow layouts
with enlarged text instead of shrinking the text.

Flyer's existing composer uses opaque themed surfaces without a blur filter.
Delivery icons fade for 140ms in a fixed 20dp box, separately from arrival effects;
initial mount, reduced motion and covered routes do not animate the status.
Neither status nor arrival motion changes message height. Reply highlighting
remains independent from both. Avatars retain real photos in compact outlined
square frames. Standard media controls are retained.
The launcher/favicon mark is generated from one small SVG in
`assets/identity/`; those icons use the Collapse mark throughout.

Draft changes are debounced and flushed on background/route disposal. Submission
captures and clears the composer synchronously; there is no global submit lock.
Flyer's `InputClearMode.never` prevents a second competing clear. Local failure
restores the captured text only if the same session's composer remains untouched;
otherwise a standard SnackBar Retry retains that failed intent without replacing
new text. Retry leaves newer drafts alone. An in-memory failure action is not
crash-proof when local storage itself is unavailable.

Implementation uses Flutter's [WidgetStateProperty](https://api.flutter.dev/flutter/widgets/WidgetStateProperty-class.html)
and [accessibility guidance](https://docs.flutter.dev/ui/accessibility/ui-design-and-styling),
not a custom animation/state framework.

## Acceptance checks

Both repositories must be checked together against their pinned local Tinode:

1. Two users register, authenticate, restart and restore their own sessions.
2. Discover a contact, open a peer profile, start a chat and exchange messages.
3. Verify text, Drafty formatting, image, file, audio, video, reply and forward.
4. Verify chat previews, unread counters and received/read status without repeated
   subscribe/leave loops on each update.
5. Queue messages and attachment bytes offline; reconnect/restart and reconcile
   acknowledgements without stranding optimistic messages.
6. Traverse more than one full window in both directions; retain the visible
   anchor, load around replies, and keep live messages from displacing history.
7. Analyze, test and build the Flutter client; independently review critical paths.

Check the current Git status before making changes and preserve unrelated work.
Commits and remote pushes require authorization for the task at hand.
Device-dependent checks and push-provider credentials must be reported separately
from automated/local-server checks. No claim of exactly-once publish delivery is
made when a server acknowledgement is lost: Tinode has no client idempotency key.

## Upstream references

- [Tinode protocol](https://github.com/tinode/chat/blob/master/docs/API.md)
- [Flyer Chat](https://pub.dev/packages/flutter_chat_ui)
- [flutter_list_view delegate](https://pub.dev/documentation/flutter_list_view/latest/flutter_list_view/FlutterListViewDelegate-class.html)
- [Flutter jumpTo activity semantics](https://api.flutter.dev/flutter/widgets/ScrollPositionWithSingleContext/jumpTo.html)
- [Drift](https://drift.simonbinder.eu/)
