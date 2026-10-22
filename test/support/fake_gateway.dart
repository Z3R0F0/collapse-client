import 'dart:async';
import 'dart:typed_data';

import 'package:collapse_tinode/collapse_tinode.dart';

class FakeGateway extends TinodeGateway {
  FakeGateway()
    : super(endpoint: Uri.parse('http://localhost:6060'), apiKey: 'test') {
    userId = 'me';
  }
  bool ready = false;
  final controller = StreamController<TinodeEvent>.broadcast();
  final List<Map<String, dynamic>> rows = [];
  final List<({int? since, int? before, int limit})> requests = [];
  final List<({String what, int? seq})> notes = [];
  final List<String> attachments = [];
  final Map<String, Map<String, dynamic>> descriptions = {};
  final Set<String> inaccessible = {};
  int uploads = 0;
  int publishes = 0;
  bool loseAck = false;
  Object? lastContent;
  Map<String, dynamic>? lastHead;
  Future<void> Function()? deleteHook;
  Future<String> Function(int call)? uploadHook;
  Future<void> Function(int call)? beforePublish;
  Future<void> Function(int call)? afterPublish;

  @override
  Future<Map<String, dynamic>> deleteMessages(
    String topic,
    List<Map<String, int>> ranges, {
    bool hard = false,
  }) async {
    await deleteHook?.call();
    return {};
  }

  @override
  bool get connected => ready;
  @override
  Stream<TinodeEvent> get events => controller.stream;
  @override
  Future<Map<String, dynamic>> attach(
    String topic, {
    Map<String, dynamic>? set,
  }) async {
    attachments.add(topic);
    return {'topic': topic};
  }

  @override
  Future<List<Map<String, dynamic>>> subscriptions({
    String topic = 'me',
  }) async => topic == 'me'
      ? [
          {
            'topic': 'usrPeer',
            'seq': rows.length,
            'public': {'fn': 'Peer'},
          },
        ]
      : [];
  @override
  Future<Map<String, dynamic>> description(String topic) async {
    if (inaccessible.contains(topic)) {
      throw const TinodeException(403, 'Access revoked');
    }
    return descriptions[topic] ??
        {
          'seq': rows.isEmpty
              ? 0
              : rows
                    .map((r) => r['seq'] as int)
                    .reduce((a, b) => a > b ? a : b),
          'public': {'fn': 'Peer'},
        };
  }

  @override
  Future<Map<String, dynamic>> deletions(String topic, {int since = 0}) async =>
      {};
  @override
  Future<List<Map<String, dynamic>>> history(
    String topic, {
    int? since,
    int? before,
    int limit = 40,
  }) async {
    requests.add((since: since, before: before, limit: limit));
    // Match Tinode's DESC semantics even for since-only queries.
    final selected =
        rows
            .where(
              (r) =>
                  (since == null || (r['seq'] as int) >= since) &&
                  (before == null || (r['seq'] as int) < before),
            )
            .toList()
          ..sort((a, b) => (b['seq'] as int).compareTo(a['seq'] as int));
    return selected.take(limit).toList();
  }

  @override
  void note(String topic, String what, {int? seq}) =>
      notes.add((what: what, seq: seq));
  @override
  Future<String> upload(
    Uint8List bytes, {
    required String name,
    required String mime,
  }) async {
    final call = ++uploads;
    if (uploadHook != null) return uploadHook!(call);
    return '/v0/file/s/file-$call';
  }

  @override
  Future<Map<String, dynamic>> publish(
    String topic, {
    required Object content,
    Map<String, dynamic> head = const {},
    String? clientId,
  }) async {
    final call = ++publishes;
    await beforePublish?.call(call);
    lastContent = content;
    lastHead = head;
    final seq = rows.length + 1;
    rows.add({
      'topic': topic,
      'seq': seq,
      'from': 'me',
      'ts': DateTime.now().toUtc().toIso8601String(),
      'content': content,
      'head': head,
    });
    await afterPublish?.call(call);
    if (loseAck) {
      loseAck = false;
      throw const TinodeException(0, 'Simulated lost acknowledgement');
    }
    return {
      'params': {'seq': seq},
    };
  }

  @override
  Future<void> dispose() async {
    await controller.close();
    await super.dispose();
  }

  void seed(int count) {
    for (var seq = 1; seq <= count; seq++) {
      rows.add({
        'topic': 'usrPeer',
        'seq': seq,
        'from': 'peer',
        'ts': DateTime(
          2026,
        ).add(Duration(seconds: seq)).toUtc().toIso8601String(),
        'content': 'message $seq',
      });
    }
  }
}
