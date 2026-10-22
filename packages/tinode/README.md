# Collapse Tinode protocol boundary

Private pure-Dart package in the client repository, not another repository or a
full SDK. Networking and MIME use maintained `web_socket_channel`, `http`, and
`http_parser`. Packet shapes reuse the existing Apache-2.0 `tinode_box` integration
and Tinode's documented client protocol. No global GetIt, Flutter dependency,
second message cache, custom socket engine, or persisted Drafty rendering tree.

The published Dart `tinode` and `tinode_community` packages are old prereleases;
the community release was published in September 2023 with a Dart `<3.0.0`
constraint. Neither is represented here as a maintained modern Dart SDK. The
official maintained JavaScript/Java/Swift SDKs remain interoperability references.

Sources:

- https://github.com/tinode/chat/blob/master/docs/API.md
- https://github.com/tinode/chat/blob/master/docs/drafty.md
- https://github.com/tinode/tinode-js
- https://pub.dev/packages/tinode
- https://pub.dev/packages/tinode_community

## Ownership and constraints

The application registers one gateway in GetIt. It owns authentication lifecycle,
retry/backoff, secure token storage, attachment policy, Drift transactions and
account isolation. `connect` performs the Tinode handshake, not authentication.
Login/account responses with status 3xx require caller-handled credential
validation. `disconnect` clears authenticated connection state. Gateways do not
log packets, URLs containing API keys, tokens, or message bodies.

`attach` is single-flight and remains attached for that session; there is no
subscribe/leave loop on presence. The caller must attach before requesting history
or publishing. The `me` topic provides `seq`, `read`, `recv` and `touched` but no
message body. Stock Tinode rejects both `me get data` and unattached `get data`.
Fresh previews for every unopened chat require attachments or a separately
negotiated server extension. Cached previews must not be misrepresented as fresh.

History is emitted on `events` and also returned after its completion `ctrl`.
Repositories must deduplicate `(account, topic, seq)`. Queries for the same topic
are serialized because historical data packets have no request ID. Live messages
may interleave; range-filter and deduplicate them. `since` is inclusive, `before`
exclusive, and results are descending even with `since`. Forward windows need
bounded sequence intervals, not unbounded `since + limit`; deleted/empty intervals
still advance coverage. The gateway does not infer gaps or end-of-history.

`head.x-client-id` is a stable optimistic-merge key, **not server idempotency**.
On an uncertain publish outcome, reconcile an echoed/queried message before an
automatic retry or explicitly accept possible duplicates. Read/recv notes are
unacknowledged; persist/coalesce/replay them at the repository boundary.

Uploads only send credentials to the configured origin, including redirects.
External attachment URLs require a separate unauthenticated media policy. Returned
relative references are resolved against `/v0/file/s/`, per protocol.
For publishes, managed `head.attachments` refs are also sent in top-level
`extra.attachments`, which establishes Tinode's file-retention links. Metadata
updates accept an explicit `attachments` list (for example, an avatar ref).
Only this server's managed relative paths enter `extra`; content stays unchanged.

DraftyCodec retains canonical JSON and unknown entities. Only outgoing composer
text is parsed by the maintained Markdown package; incoming/forwarded content is
never reinterpreted. Tinode 0.25 wire offsets count grapheme clusters. Presentation
applies URL allowlists and renders unknown entities safely.

Replies use a bounded rich excerpt, following the official
[replyContent approach](https://github.com/tinode/tinode-js/blob/v0.25.1/src/drafty.js#L1502):
remove nested QQ/legacy QR and hidden HD text, retain surviving styles/links,
move at most three out-of-band attachments into the quote, and lighten media.
An excerpt is at most 256 graphemes and 16 KiB JSON; inline values/previews are
retained up to 4 KiB. Remote media refs remain usable. An inline-only attachment
too large to quote becomes a readable filename/media marker instead of a broken
image. Exceptional aggregate overflow falls back to bounded text/filenames.
These limits never modify the original message, new reply body or forwarding,
and are not a replacement for the server's whole-message size limit.

Run `dart test` and `dart analyze` in this directory.
