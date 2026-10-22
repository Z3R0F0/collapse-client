import 'dart:async';

import 'package:collapse/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/media_gallery_fixture.dart';

class _BackfillGateDatabase extends AppDatabase {
  _BackfillGateDatabase() : super.forTesting(NativeDatabase.memory());
  Completer<void>? beforeNextTransaction;
  final entered = Completer<void>();

  @override
  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool requireNew = false,
  }) async {
    final gate = beforeNextTransaction;
    if (gate != null) {
      beforeNextTransaction = null;
      entered.complete();
      // Hold before opening SQLite's transaction, so clearScope can finish.
      await gate.future;
    }
    return super.transaction(action, requireNew: requireNew);
  }
}

void main() {
  test(
    'deferred media backfill cannot recreate a cleared account cache',
    () async {
      final db = _BackfillGateDatabase();
      final gate = Completer<void>();
      Future<bool>? preparing;
      try {
        await db.mergeTopic(galleryScope, galleryTopic, {'seq': 10});
        await db.mergeMessage(
          galleryScope,
          galleryMessage(10, galleryPhoto()),
          'me',
        );
        // Existing v2 message rows have not had their new atlas index built yet.
        await db.clearMedia(galleryScope, galleryTopic);
        expect(await db.select(db.messages).get(), hasLength(1));
        db.beforeNextTransaction = gate;
        preparing = db.prepareMedia(galleryScope, galleryTopic);
        await db.entered.future;
        await db.clearScope(galleryScope);
        expect(await db.select(db.messages).get(), isEmpty);
        gate.complete();
        await preparing;
        expect(
          await db.select(db.mediaEntries).get(),
          isEmpty,
          reason:
              'Backfill must read its source after entering the same transaction as its writes',
        );
        expect(await db.select(db.messages).get(), isEmpty);
        expect(await db.select(db.topics).get(), isEmpty);
      } finally {
        if (!gate.isCompleted) gate.complete();
        await preparing;
        await db.close();
      }
    },
  );
}
