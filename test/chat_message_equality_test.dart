import 'dart:convert';

import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rehydrated messages compare by all protocol and delivery fields', () {
    final first = _message();
    final decoded = _message();
    expect(first, decoded);
    expect(first.hashCode, decoded.hashCode);
    for (final changed in [
      _message(id: 'another'),
      _message(topicId: 'another'),
      _message(seq: 2),
      _message(localSeq: 2),
      _message(senderId: 'another'),
      _message(createdAt: DateTime.utc(2026, 2)),
      _message(content: {'txt': 'different'}),
      _message(head: {'reply': 2}),
      _message(delivery: Delivery.read),
      _message(hidden: true),
    ]) {
      expect(first, isNot(changed));
    }
  });

  test('nested attachment changes differ but map insertion order does not', () {
    final first = _message();
    expect(
      first,
      _message(
        content: {
          'ent': [
            {
              'data': {'ref': '/v0/file/s/image'},
              'tp': 'IM',
            },
          ],
          'txt': ' ',
        },
      ),
    );
    expect(
      first,
      isNot(
        _message(
          content: {
            'txt': ' ',
            'ent': [
              {
                'tp': 'IM',
                'data': {'ref': '/v0/file/s/new-image'},
              },
            ],
          },
        ),
      ),
    );
  });
}

ChatMessage _message({
  String id = 'stable',
  String topicId = 'usrPeer',
  int seq = 1,
  int localSeq = 1,
  String senderId = 'me',
  DateTime? createdAt,
  Object? content,
  Map<String, dynamic>? head,
  Delivery delivery = Delivery.sent,
  bool hidden = false,
}) => ChatMessage(
  id: id,
  topicId: topicId,
  seq: seq,
  localSeq: localSeq,
  senderId: senderId,
  createdAt: createdAt ?? DateTime.utc(2026),
  content:
      content ??
      jsonDecode(
            '{"txt":" ","ent":[{"tp":"IM","data":{"ref":"/v0/file/s/image"}}]}',
          )
          as Object,
  head: head ?? {'reply': 1},
  delivery: delivery,
  hidden: hidden,
);
