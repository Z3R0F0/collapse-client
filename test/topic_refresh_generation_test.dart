import 'dart:async';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse_tinode/collapse_tinode.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class _HeldRefreshGateway extends FakeGateway {
  final captured = Completer<void>();
  final release = Completer<void>();
  bool holdNext = false;
  final sent = <({String? user, String what, int? seq})>[];

  @override
  Future<List<Map<String, dynamic>>> history(
    String topic, {
    int? since,
    int? before,
    int limit = 40,
  }) async {
    final hold = holdNext;
    holdNext = false;
    final rows = await super.history(
      topic,
      since: since,
      before: before,
      limit: limit,
    );
    if (hold) {
      captured.complete();
      await release.future;
    }
    return rows;
  }

  @override
  void note(String topic, String what, {int? seq}) {
    sent.add((user: userId, what: what, seq: seq));
    super.note(topic, what, seq: seq);
  }
}

class _HeldReceiptDatabase extends AppDatabase {
  _HeldReceiptDatabase() : super.forTesting(NativeDatabase.memory());
  final captured = Completer<void>(), release = Completer<void>();
  bool holdNext = false;

  @override
  Future<void> receipts(
    String scope,
    String topicId,
    String userId, {
    int? read,
    int? recv,
    int? peerRead,
    int? peerRecv,
  }) async {
    final hold = holdNext && recv != null;
    if (hold) holdNext = false;
    await super.receipts(
      scope,
      topicId,
      userId,
      read: read,
      recv: recv,
      peerRead: peerRead,
      peerRecv: peerRecv,
    );
    if (hold) {
      captured.complete();
      await release.future;
    }
  }
}

void main() {
  for (final sameAccount in [false, true]) {
    test(
      'old refresh cannot send receipts after ${sameAccount ? 'same-account relogin' : 'account switch'}',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final gateway = _HeldRefreshGateway()..seed(5);
        final repo = ChatsRepository(
          database: db,
          gateway: gateway,
          serverId: 'local',
        );
        Future<void>? oldRefresh;
        try {
          await repo.start('me');
          await db.mergeTopic('local|me', 'usrPeer', {
            'seq': 80,
            'read': 70,
            'recv': 80,
          });
          gateway.holdNext = true;
          gateway.ready = true;
          oldRefresh = repo.refreshTopics();
          await gateway.captured.future.timeout(const Duration(seconds: 3));
          gateway.ready = false;
          await repo.stop();
          final replacement = sameAccount ? 'me' : 'other';
          gateway.userId = replacement;
          gateway.rows.clear();
          gateway.seed(2);
          gateway.ready = true;
          await repo.start(replacement);
          // Legitimate new-session sync is complete. Only the old fetch remains.
          gateway.sent.clear();
          gateway.release.complete();
          await oldRefresh.timeout(const Duration(seconds: 3));
          expect(
            gateway.sent,
            isEmpty,
            reason:
                'a late old fetch must not emit old watermarks on the current socket',
          );
          expect((await db.topicRow('local|me', 'usrPeer'))!.readSeq, 70);
          if (!sameAccount) {
            expect((await db.topicRow('local|other', 'usrPeer'))!.readSeq, 0);
          }
        } finally {
          if (!gateway.release.isCompleted) gateway.release.complete();
          await oldRefresh;
          await repo.dispose();
          await gateway.dispose();
          await db.close();
        }
      },
    );

    test(
      'late receive storage cannot notify ${sameAccount ? 'a replacement same-account session' : 'another account'}',
      () async {
        final db = _HeldReceiptDatabase();
        final gateway = _HeldRefreshGateway();
        final repo = ChatsRepository(
          database: db,
          gateway: gateway,
          serverId: 'local',
        );
        try {
          await repo.start('me');
          await db.mergeTopic('local|me', 'usrPeer', {'seq': 1});
          db.holdNext = true;
          gateway.ready = true;
          gateway.controller.add(
            const TinodeEvent('data', {
              'topic': 'usrPeer',
              'seq': 1,
              'from': 'peer',
              'content': 'received before logout',
            }),
          );
          await db.captured.future.timeout(const Duration(seconds: 3));
          gateway.ready = false;
          await repo.stop();
          gateway.userId = sameAccount ? 'me' : 'other';
          await repo.start(gateway.userId!);
          gateway.ready = true;
          await repo.ensureTopic('usrPeer');
          gateway.sent.clear();
          final drained = repo
              .changesFor('usrPeer')
              .firstWhere((change) => change.reset);
          db.release.complete();
          gateway.controller.add(
            const TinodeEvent('info', {
              'topic': 'usrPeer',
              'from': 'peer',
              'what': 'recv',
              'seq': 0,
            }),
          );
          await drained.timeout(const Duration(seconds: 3));
          expect(
            gateway.sent,
            isEmpty,
            reason:
                'storage may complete for the old account, but cannot use a new socket',
          );
          expect((await db.topicRow('local|me', 'usrPeer'))!.recvSeq, 1);
          if (!sameAccount) {
            expect((await db.topicRow('local|other', 'usrPeer'))!.recvSeq, 0);
          }
        } finally {
          if (!db.release.isCompleted) db.release.complete();
          await repo.dispose();
          await gateway.dispose();
          await db.close();
        }
      },
    );
  }
}
