import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_list_view/flutter_list_view.dart';

export 'package:flutter_list_view/flutter_list_view.dart'
    show FlutterListViewController;

part 'message_list_paging.dart';
part 'message_list_visibility.dart';
part 'message_list_view.dart';

/// One viewport owner. Paging preserves keyed rows during layout; navigation
/// supplies a new snapshot and epoch instead of scrolling through history.
class MessageList extends StatefulWidget {
  const MessageList({
    super.key,
    required this.messages,
    required this.itemBuilder,
    required this.controller,
    required this.canLoadOlder,
    required this.canLoadNewer,
    required this.atLatest,
    required this.onLoadOlder,
    required this.onLoadNewer,
    required this.onFollowingChanged,
    this.navigationEpoch = 0,
    this.targetId,
    this.navigating = false,
    this.bottomInset = 0,
    this.empty,
    this.onVisibleIds,
    this.olderPageKey,
    this.newerPageKey,
    this.rebaseAnchorId,
    this.rowPresentation,
  });

  final List<chat.Message> messages;
  final chat.ChatItem itemBuilder;
  final FlutterListViewController controller;
  final bool canLoadOlder, canLoadNewer, atLatest, navigating;
  final Future<void> Function() onLoadOlder, onLoadNewer;
  final ValueChanged<bool> onFollowingChanged;
  final ValueChanged<Set<String>>? onVisibleIds;

  /// Repository cursor progress, including covered ranges with no visible rows.
  final Object? olderPageKey, newerPageKey;
  final int navigationEpoch;

  /// Null means latest. Change [navigationEpoch] with the ready snapshot.
  final String? targetId;

  /// A canonical-order rebase preserves this painted key instead of following
  /// an apparent arrival at the end of the replacement snapshot.
  final String? rebaseAnchorId;

  /// Refreshes row-only presentation (e.g. reply highlight), never list layout.
  final Object? rowPresentation;
  final double bottomInset;
  final Widget? empty;

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  int? _appliedEpoch;
  int _initialIndex = 0, _positionEpoch = 0;
  bool _alignBottom = true, _following = false, _userScrolling = false;
  bool _loadingPage = false;
  bool _rebasing = false;
  bool? _pagingOlder;
  bool? _reportedFollowing;
  final _requestedPages = <bool, Object?>{};
  Set<String> _visibleIds = const {};
  double? _height, _width;
  double _initialOffset = 0;
  ({String id, double offset})? _paintedAnchor;
  final _rows = ValueNotifier<List<chat.Message>>(const []);
  FlutterListView? _list;
  List<String> _listIds = const [];
  int _listPosition = -1;

  @override
  void initState() {
    super.initState();
    _rows.value = List.unmodifiable(widget.messages);
  }

  @override
  void didUpdateWidget(covariant MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = _rows.value;
    if (!listEquals(previous, widget.messages) ||
        oldWidget.rowPresentation != widget.rowPresentation ||
        oldWidget.itemBuilder != widget.itemBuilder) {
      // ChatController exposes a mutable list. Keep our own bounded snapshot.
      _rows.value = List.unmodifiable(widget.messages);
    }
    if (widget.rebaseAnchorId != null &&
        (oldWidget.rebaseAnchorId != widget.rebaseAnchorId ||
            !listEquals(previous, widget.messages))) {
      _rebasing = true;
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.sliverController.onPaintItemPositionsCallback = null;
    }
    if (oldWidget.navigationEpoch != widget.navigationEpoch ||
        widget.navigating) {
      _userScrolling = false;
    }
    if (oldWidget.navigationEpoch != widget.navigationEpoch) {
      _requestedPages.clear();
    }
    if (_following &&
        !_rebasing &&
        !widget.navigating &&
        previous.lastOrNull?.id != widget.messages.lastOrNull?.id) {
      _place(null);
    }
  }

  bool _place(String? id, {double offset = 0}) {
    if (widget.messages.isEmpty) return false;
    final index = id == null
        ? widget.messages.length - 1
        : widget.messages.indexWhere((message) => message.id == id);
    if (index < 0) return false;
    _initialIndex = index;
    _initialOffset = offset;
    _alignBottom = id == null;
    _positionEpoch++;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    _trackVisible(widget.messages);
    if (_appliedEpoch != widget.navigationEpoch && _place(widget.targetId)) {
      _appliedEpoch = widget.navigationEpoch;
      // Explicit latest remains tail-follow intent even when its initial cache
      // snapshot ends before a missing server interval. Geometry cancels it
      // when the user leaves; a targeted history navigation never enables it.
      _following = widget.targetId == null;
      _paintedAnchor = null;
      _height = null;
      _width = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebasing = false;
      _reportFollowing();
    });
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomInset),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final widthChanged = _width != null && _width != constraints.maxWidth;
          final heightChanged =
              _height != null && _height != constraints.maxHeight;
          final anchor = _paintedAnchor;
          if (!_rebasing && (widthChanged || heightChanged)) {
            if (_following) {
              _place(null);
            } else if (widthChanged && anchor != null) {
              // Rewrapping cached predecessors is not a data-window change.
              // Let the indexed list retain this painted key during layout.
              _place(anchor.id, offset: anchor.offset);
            }
          }
          _height = constraints.maxHeight;
          _width = constraints.maxWidth;
          return NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildList(),
                if (widget.messages.isEmpty && widget.empty != null)
                  widget.empty!,
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.sliverController.onPaintItemPositionsCallback = null;
    _rows.dispose();
    super.dispose();
  }
}
