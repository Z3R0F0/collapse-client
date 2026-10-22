import 'dart:async';

import 'package:collapse_tinode/collapse_tinode.dart';

import 'fake_gateway.dart';
import 'window_race_fixture.dart';

class ArrivalGateway extends FakeGateway {
  final historyGates = <ReadGate<List<Map<String, dynamic>>>>[];
  ReadGate<Map<String, dynamic>>? deletionGate;
  bool emitHistory = false;

  @override
  Future<List<Map<String, dynamic>>> history(
    String topic, {
    int? since,
    int? before,
    int limit = 40,
  }) async {
    final gate = historyGates.isEmpty ? null : historyGates.removeAt(0);
    final rows = await super.history(
      topic,
      since: since,
      before: before,
      limit: limit,
    );
    if (emitHistory) {
      for (final row in rows) {
        controller.add(TinodeEvent('data', {...row, 'topic': topic}));
      }
      await Future<void>.delayed(Duration.zero);
    }
    return gate == null ? rows : gate.pause(rows);
  }

  @override
  Future<Map<String, dynamic>> deletions(String topic, {int since = 0}) async {
    final gate = deletionGate;
    deletionGate = null;
    return gate == null ? {} : gate.pause({});
  }
}

Map<String, dynamic> arrivalPacket(int seq, {String topic = 'usrPeer'}) => {
  'topic': topic,
  'seq': seq,
  'from': 'peer',
  'ts': DateTime.utc(2026).add(Duration(seconds: seq)).toIso8601String(),
  'content': 'message $seq',
};
