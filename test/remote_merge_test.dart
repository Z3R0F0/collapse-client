import 'dart:io';

import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final deleting in [false, true]) {
    test(
      '${deleting ? 'deletion' : 'merge'} owns coverage in one transaction',
      () async {
        final database = AppDatabase.forTesting(
          NativeDatabase.memory().interceptWith(_SingleOwnerTransactions()),
        );
        try {
          await database.mergeTopic('fixture|me', 'usrPeer', {'seq': 1});
          if (deleting) {
            await database.applyDeletions('fixture|me', 'usrPeer', [
              {'low': 1, 'hi': 2},
            ], 1);
          } else {
            await database.mergeMessage(
              'fixture|me',
              ChatMessage(
                id: 'usrPeer:1',
                topicId: 'usrPeer',
                seq: 1,
                localSeq: 0,
                senderId: 'peer',
                createdAt: DateTime.utc(2026),
                content: 'fixture',
              ),
              'me',
            );
          }
          expect(
            (await database.topicRow('fixture|me', 'usrPeer'))!.coverage,
            '[[1,2]]',
          );
          await database.recordCoverage('fixture|me', 'usrPeer', 2, 3);
          expect(
            (await database.topicRow('fixture|me', 'usrPeer'))!.coverage,
            '[[1,3]]',
          );
        } finally {
          await database.close();
        }
      },
    );
  }

  for (final count in [1, 40]) {
    test(
      'remote executor concurrently merges duplicate $count-message history',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'collapse_remote_probe_',
        );
        final database = AppDatabase.forTesting(
          NativeDatabase.createInBackground(
            File('${directory.path}/probe.sqlite'),
          ),
        );
        try {
          await database.mergeTopic('fixture|me', 'usrPeer', {'seq': 600});
          Future<void> mergePage() async {
            for (var seq = 600; seq > 600 - count; seq--) {
              await database.mergeMessage(
                'fixture|me',
                ChatMessage(
                  id: 'usrPeer:$seq',
                  topicId: 'usrPeer',
                  seq: seq,
                  localSeq: 0,
                  senderId: 'peer',
                  createdAt: DateTime.utc(2026),
                  content: 'fixture',
                ),
                'me',
              );
            }
          }

          await Future.wait([
            mergePage(),
            mergePage(),
          ]).timeout(const Duration(seconds: 5));
          expect(
            await database.page('fixture|me', 'usrPeer'),
            hasLength(count),
          );
        } finally {
          await database.close().timeout(const Duration(seconds: 2));
          await directory.delete(recursive: true);
        }
      },
      timeout: const Timeout(Duration(seconds: 12)),
    );
  }
}

// Drift 2.34.4 OPFS reuses a navigator-lock interceptor for nested transactions.
// Coverage already has an atomic owner; prevent reintroducing that extra scope.
class _SingleOwnerTransactions extends QueryInterceptor {
  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    if (parent is TransactionExecutor) {
      throw StateError('Coverage must use its existing transaction owner');
    }
    return super.beginTransaction(parent);
  }
}
