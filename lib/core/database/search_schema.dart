part of 'app_database.dart';

extension _SearchSchema on AppDatabase {
  Future<void> _createSearchIndex() async {
    // Standard external-content FTS5. Explicit IDs remain stable across VACUUM.
    await customStatement('''
      CREATE VIRTUAL TABLE message_fts USING fts5(
        body, content='message_search', content_rowid='id',
        tokenize='unicode61 remove_diacritics 0', prefix='2 3'
      )
    ''');
    await customStatement('''
      CREATE TRIGGER search_insert AFTER INSERT ON message_search BEGIN
        INSERT INTO message_fts(rowid, body) VALUES (new.id, new.body);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER search_delete AFTER DELETE ON message_search BEGIN
        INSERT INTO message_fts(message_fts, rowid, body)
          VALUES ('delete', old.id, old.body);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER search_update AFTER UPDATE OF body ON message_search
      WHEN old.body IS NOT new.body BEGIN
        INSERT INTO message_fts(message_fts, rowid, body)
          VALUES ('delete', old.id, old.body);
        INSERT INTO message_fts(rowid, body) VALUES (new.id, new.body);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER message_search_delete AFTER DELETE ON messages BEGIN
        DELETE FROM message_search WHERE scope=old.scope
          AND topic_id=old.topic_id AND seq=old.seq;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER message_search_hide AFTER UPDATE OF hidden, deleted
      ON messages WHEN new.hidden OR new.deleted BEGIN
        UPDATE message_search SET body='' WHERE scope=new.scope
          AND topic_id=new.topic_id AND seq=new.seq;
      END
    ''');
  }
}
