# Message formatting

Composer input uses Telegram-style double delimiters, not Bot API MarkdownV2.
Only outgoing text is parsed. Existing messages and forwards remain unchanged.
In the web composer, Enter sends and Shift+Enter inserts a new line.

| Input | Result |
| --- | --- |
| `**bold**` | Bold |
| `__italic__` | Italic, not underline |
| `~~removed~~` | Strikethrough |
| `\|\|hidden\|\|` | Spoiler; tap or keyboard-activate to reveal |
| Single backticks | Literal monospace code |
| Triple-backtick fence, optional language | Literal multiline code; language retained in Drafty |
| `[label](https://example.org)` | Link; HTTP(S)/mailto only |

Nested styles, backslash escapes, unfinished delimiters, composed emoji and
combining characters are covered by tests. Code contents are never reparsed.
Blank lines between paragraphs are retained. Explicit Copy restores line breaks
and includes spoiler text. The original source draft is not modified by parsing.

## Compatibility boundary

There is no single identical typed-Markdown grammar across Telegram clients.
The shared core above follows the delimiter choices in
[Telegram Desktop](https://github.com/desktop-app/lib_ui/blob/ae492d4015ce35daf697053776c79786ea7d9282/ui/widgets/fields/input_field.cpp)
and [Telegram Android](https://github.com/DrKLO/Telegram/blob/9552e5541e1274b9557c9832b204dbfcaf44b3dc/TMessagesProj/src/main/java/org/telegram/messenger/MediaDataController.java).
Collapse deliberately retains its existing CommonMark/GFM links, headings, lists,
tables, quotes, single-emphasis aliases, escaping and nesting rules. These are
Collapse extensions, not a claim of exact Telegram boundary/escape behaviour.

Underline, expandable quotes, mention-by-user-ID and custom emoji in Telegram
are rich-editor/API entities, not all expressible through ordinary typed
delimiters. This change does not add those editor features or Telegram's media
API. It does not implement [Bot API MarkdownV2](https://core.telegram.org/bots/api#markdownv2-style),
syntax highlighting, or live formatting inside the composer.

## Drafty and spoilers

ST/EM/DL/CO/LN/QQ remain standard Drafty. Code blocks use a CO entity with
optional `block`/`language` data; older renderers still display monospace text.
Offsets remain Tinode graphemes, not Telegram's UTF-16 offsets.

Spoilers are a small Collapse extension of HD: `data.spoiler` holds a canonical
Drafty fragment. The outer `txt` contains only a same-length mask. All nested
link targets are inside the fragment; a wholly hidden link label also keeps its
target there. A partially public link label still has a public URL.

Stock Tinode's plain/push previews see only the mask, and its lightweight
previews drop the fragment. Other clients do not gain reveal support: they may
show the mask or omit HD. This is visual concealment, not encryption or access
control; recipients receive the original fragment. Forward preserves it.

Collapse excludes spoilers from previews, search, reply excerpts and accessibility
until reveal. The hidden glyphs are not painted (including colour emoji), and
hidden links cannot receive taps. Reveal keeps the exact layout footprint.
Reveal state belongs to the mounted message widget, never the pagination or
delivery state. It may reset when an old row is evicted/remounted; resizing and
receipt updates do not reset it. Untrusted nested fragments have a depth limit.
