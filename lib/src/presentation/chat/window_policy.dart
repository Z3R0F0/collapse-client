import '../../domain/chat/chat_models.dart';

/// Shared UI bounds. Membership and ordering belong to the repository snapshot.
class WindowPolicy {
  static const pageSize = 40;
  static const capacity = 120;

  static int? oldest(List<ChatMessage> messages) =>
      messages.where((m) => !m.pending).firstOrNull?.seq;
  static int? newest(List<ChatMessage> messages) =>
      messages.where((m) => !m.pending).lastOrNull?.seq;
}
