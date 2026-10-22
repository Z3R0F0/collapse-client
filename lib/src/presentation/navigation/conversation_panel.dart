import 'package:flutter/widgets.dart';

/// Presentation only. The URL owns which panel/message is selected.
class ConversationPanel extends InheritedWidget {
  const ConversationPanel({
    super.key,
    required this.besideChat,
    required super.child,
  });
  final bool besideChat;
  static bool isBesideChat(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ConversationPanel>()
          ?.besideChat ??
      false;
  @override
  bool updateShouldNotify(ConversationPanel oldWidget) =>
      oldWidget.besideChat != besideChat;
}
