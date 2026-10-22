import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme.dart';
import '../../../dependency_injection.dart';
import '../../../widgets/view_activity.dart';
import '../../data/chat/chats_repository.dart';
import '../../domain/chat/chat_models.dart';
import '../chat/chat_cubit.dart';
import '../chat/chat_screen.dart';
import 'app_routes.dart';
import 'app_navigation.dart';
import 'conversation_panel.dart';

/// The conversation owns one Cubit/screen. Info/search only change pane geometry.
class ConversationShell extends StatefulWidget {
  const ConversationShell({
    super.key,
    required this.topic,
    required this.userId,
    required this.uri,
    required this.panel,
  });
  final String topic;
  final String userId;
  final Uri uri;
  final Widget panel;
  @override
  State<ConversationShell> createState() => _ConversationShellState();
}

class _ConversationShellState extends State<ConversationShell> {
  late final ChatCubit _chat;
  late final Stream<ChatTopic?> _topic;
  int? get _message {
    final value = int.tryParse(widget.uri.queryParameters['message'] ?? '');
    return value != null && value > 0 ? value : null;
  }

  String? get _local {
    final value = widget.uri.queryParameters['local'];
    return _message == null &&
            value != null &&
            value.isNotEmpty &&
            value.length <= 128
        ? value
        : null;
  }

  @override
  void initState() {
    super.initState();
    _chat = locator<ChatCubit>()
      ..open(widget.topic, aroundSeq: _message, aroundId: _local);
    _topic = context.read<ChatsRepository>().watchTopic(widget.topic);
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _chat,
    child: StreamBuilder<ChatTopic?>(
      stream: _topic,
      builder: (context, snapshot) => LayoutBuilder(
        builder: (context, constraints) {
          final panelOpen = const {
            'info',
            'search',
          }.contains(widget.uri.pathSegments.elementAtOrNull(2));
          final sideBySide = constraints.maxWidth >= 860;
          final panelWidth = sideBySide ? 360.0 : constraints.maxWidth;
          final chatWidth = panelOpen && sideBySide
              ? constraints.maxWidth - panelWidth
              : constraints.maxWidth;
          return Stack(
            children: [
              PositionedDirectional(
                key: const ValueKey('conversation-pane'),
                start: 0,
                top: 0,
                bottom: 0,
                width: chatWidth,
                child: Offstage(
                  offstage: panelOpen && !sideBySide,
                  child: ViewActivity(
                    active: !panelOpen || sideBySide,
                    child: ChatScreen(
                      key: ValueKey(widget.topic),
                      topicId: widget.topic,
                      userId: widget.userId,
                      title: snapshot.data?.title ?? widget.topic,
                      targetSeq: _message,
                      targetId: _local,
                      onBack: () => AppNavigation.back(
                        context,
                        fallback: AppRoutes.chats,
                      ),
                      onProfile: () => AppNavigation.open(
                        context,
                        AppRoutes.withTarget(
                          Uri.parse(AppRoutes.info(widget.topic)),
                          message: _message,
                          local: _local,
                        ),
                      ),
                      onSearch: () => AppNavigation.open(
                        context,
                        AppRoutes.withTarget(
                          Uri.parse(AppRoutes.search(widget.topic)),
                          message: _message,
                          local: _local,
                        ),
                      ),
                      onMessageTarget: (seq, id) => AppNavigation.open(
                        context,
                        AppRoutes.withTarget(
                          widget.uri,
                          message: seq > 0 ? seq : null,
                          local: seq > 0 ? null : id,
                        ),
                      ),
                      onClearTarget: () => AppNavigation.replace(
                        context,
                        AppRoutes.withTarget(widget.uri),
                      ),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                key: const ValueKey('conversation-details'),
                end: 0,
                top: 0,
                bottom: 0,
                width: panelWidth,
                child: Offstage(
                  offstage: !panelOpen,
                  child: ViewActivity(
                    active: panelOpen,
                    child: DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        border: BorderDirectional(
                          start: BorderSide(
                            color: context.colors.outlineVariant,
                          ),
                        ),
                      ),
                      child: ConversationPanel(
                        besideChat: sideBySide,
                        child: Semantics(
                          container: true,
                          explicitChildNodes: true,
                          child: widget.panel,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  @override
  void dispose() {
    unawaited(_chat.close());
    super.dispose();
  }
}
