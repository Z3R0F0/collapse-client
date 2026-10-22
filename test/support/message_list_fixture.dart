import 'package:collapse/src/presentation/chat/message_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;

List<int> messagePage(int start, [int count = 120]) =>
    List.generate(count, (index) => start + index);

double messageHeight(int id) => id % 9 == 0 ? 620 : 52 + (id % 7) * 23;

class MessageListFixture extends StatefulWidget {
  const MessageListFixture({super.key});
  @override
  State<MessageListFixture> createState() => MessageListFixtureState();
}

class MessageListFixtureState extends State<MessageListFixture> {
  final controller = FlutterListViewController();
  List<int> ids = messagePage(240);
  String delivery = 'queued';
  String? target = '300';
  String? rebaseAnchorId;
  int epoch = 0, olderCalls = 0, newerCalls = 0;
  bool older = true, newer = true, atLatest = false, navigating = false;
  double inset = 0;
  Object? olderPageKey, newerPageKey;
  final following = <bool>[];
  Set<String> visibleIds = {};
  Future<void> Function()? olderAction, newerAction;

  void change(VoidCallback action) => setState(action);
  void replace(List<int> next) => change(() => ids = next);
  void latest(List<int> next, {double bottomInset = 0}) => change(() {
    ids = next;
    target = null;
    rebaseAnchorId = null;
    epoch++;
    newer = false;
    atLatest = true;
    inset = bottomInset;
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: MessageList(
        messages: [
          for (final id in ids)
            chat.Message.custom(
              id: '$id',
              authorId: 'peer',
              metadata: {'delivery': delivery},
            ),
        ],
        controller: controller,
        canLoadOlder: older,
        canLoadNewer: newer,
        atLatest: atLatest,
        navigationEpoch: epoch,
        targetId: target,
        rebaseAnchorId: rebaseAnchorId,
        navigating: navigating,
        bottomInset: inset,
        onFollowingChanged: following.add,
        onVisibleIds: (ids) => visibleIds = ids,
        olderPageKey: olderPageKey,
        newerPageKey: newerPageKey,
        onLoadOlder: () async {
          olderCalls++;
          await olderAction?.call();
        },
        onLoadNewer: () async {
          newerCalls++;
          await newerAction?.call();
        },
        itemBuilder:
            (
              context,
              message,
              index,
              animation, {
              messagesGroupingMode,
              messageGroupingTimeoutInSeconds,
              isRemoved,
            }) => MessageListProbe(
              key: ValueKey('row-${message.id}'),
              id: int.parse(message.id),
              delivery: message.metadata!['delivery'] as String,
            ),
      ),
    ),
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class MessageListProbe extends StatefulWidget {
  const MessageListProbe({super.key, required this.id, required this.delivery});
  final int id;
  final String delivery;
  @override
  State<MessageListProbe> createState() => MessageListProbeState();
}

class MessageListProbeState extends State<MessageListProbe> {
  late final int originalId = widget.id;
  int localCounter = 0;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: messageHeight(widget.id),
    child: Text('${widget.id} ${widget.delivery} $localCounter'),
  );
}
