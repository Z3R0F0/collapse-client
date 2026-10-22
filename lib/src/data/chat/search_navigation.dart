part of 'chats_repository.dart';

extension _SearchNavigation on ChatsRepository {
  Future<List<ChatMessage>> _loadAroundId(
    String topicId,
    String clientId, {
    int limit = 40,
  }) async =>
      (await openHistory(
        topicId,
        aroundId: clientId,
        limit: limit,
      ))?.messages ??
      [];
}
