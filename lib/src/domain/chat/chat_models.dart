import 'dart:typed_data';

import 'package:collection/collection.dart';

enum Delivery { queued, sending, sent, received, read, failed }

class ChatTopic {
  const ChatTopic({
    required this.id,
    required this.title,
    this.avatarRef,
    this.online = false,
    this.serverSeq = 0,
    this.readSeq = 0,
    this.recvSeq = 0,
    this.peerReadSeq = 0,
    this.peerRecvSeq = 0,
    this.unreadCount = 0,
    this.lastPreview = '',
    this.lastMessageAt,
    this.draft = '',
    this.isGroup = false,
  });

  final String id;
  final String title;
  final String? avatarRef;
  final bool online;
  final int serverSeq;
  final int readSeq;
  final int recvSeq;
  final int peerReadSeq;
  final int peerRecvSeq;
  final int unreadCount;
  final String lastPreview;
  final DateTime? lastMessageAt;
  final String draft;
  final bool isGroup;
}

/// Raw Tinode content and headers are protocol data, never rebuilt from [text].
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.topicId,
    required this.seq,
    required this.localSeq,
    required this.senderId,
    required this.createdAt,
    required this.content,
    this.head = const {},
    this.delivery = Delivery.sent,
    this.hidden = false,
  });

  final String id;
  final String topicId;
  final int seq;
  final int localSeq;
  final String senderId;
  final DateTime createdAt;
  final Object content;
  final Map<String, dynamic> head;
  final Delivery delivery;
  final bool hidden;

  String get text => content is Map
      ? ((content as Map)['txt']?.toString() ?? '')
      : content.toString();

  bool get pending => seq < 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          id == other.id &&
          topicId == other.topicId &&
          seq == other.seq &&
          localSeq == other.localSeq &&
          senderId == other.senderId &&
          createdAt == other.createdAt &&
          const DeepCollectionEquality().equals(content, other.content) &&
          const DeepCollectionEquality().equals(head, other.head) &&
          delivery == other.delivery &&
          hidden == other.hidden;

  @override
  int get hashCode => Object.hash(
    id,
    topicId,
    seq,
    localSeq,
    senderId,
    createdAt,
    const DeepCollectionEquality().hash(content),
    const DeepCollectionEquality().hash(head),
    delivery,
    hidden,
  );
}

/// Bytes are committed to Drift before any upload or publish starts.
class PendingUpload {
  const PendingUpload({
    required this.entityIndex,
    required this.bytes,
    required this.name,
    required this.mime,
  });

  final int entityIndex;
  final Uint8List bytes;
  final String name;
  final String mime;
}

class MessagePage {
  const MessagePage(this.messages, {required this.hasMore});
  final List<ChatMessage> messages;
  final bool hasMore;
}

/// Transport/storage provenance, not a persistent animation or delivery state.
enum ChatChangeOrigin { update, history, arrival }

/// Lifecycle of one background metadata/tail reconciliation, not pagination.
enum HistorySyncPhase { started, completed, failed }

class ChatChange {
  const ChatChange(
    this.topicId, {
    this.message,
    this.reset = false,
    this.origin = ChatChangeOrigin.update,
    this.historySync,
  });
  final String topicId;
  final ChatMessage? message;
  final bool reset;
  final ChatChangeOrigin origin;
  final HistorySyncPhase? historySync;
}
