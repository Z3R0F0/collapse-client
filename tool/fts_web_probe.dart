// Run against web/sqlite3.wasm, not an alternative database build.
// dart compile js -o .local/fts_web_probe.js tool/fts_web_probe.dart
import 'dart:convert';
import 'dart:js_interop';
import 'package:sqlite3/wasm.dart';

@JS('globalThis.collapseFtsProbe')
external set result(JSString value);

Future<void> main() async {
  try {
    final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
    sqlite.registerVirtualFileSystem(InMemoryFileSystem(), makeDefault: true);
    final db = sqlite.openInMemory();
    try {
      db.execute('CREATE TABLE bodies(id INTEGER PRIMARY KEY, body TEXT)');
      db.execute(
        "CREATE VIRTUAL TABLE ft USING fts5(body, content='bodies', "
        "content_rowid='id', tokenize='unicode61 remove_diacritics 0', prefix='2 3')",
      );
      db.execute(
        'CREATE TRIGGER bodies_ai AFTER INSERT ON bodies BEGIN '
        'INSERT INTO ft(rowid,body) VALUES(new.id,new.body); END',
      );
      db.execute(
        "CREATE TRIGGER bodies_ad AFTER DELETE ON bodies BEGIN "
        "INSERT INTO ft(ft,rowid,body) VALUES('delete',old.id,old.body); END",
      );
      db.execute(
        "CREATE TRIGGER bodies_au AFTER UPDATE ON bodies BEGIN "
        "INSERT INTO ft(ft,rowid,body) VALUES('delete',old.id,old.body); "
        "INSERT INTO ft(rowid,body) VALUES(new.id,new.body); END",
      );
      db.execute('INSERT INTO bodies VALUES(1, ?)', ['ПрИвЕт Hello ЁЛКА']);
      for (final word in ['ПРИВ', 'привет', 'hello', 'HEL', 'ёлк']) {
        final rows = db.select('SELECT rowid FROM ft WHERE ft MATCH ?', [
          '"$word"*',
        ]);
        if (rows.length != 1) throw StateError('RU/EN prefix mismatch');
      }
      for (final word in ['рив', 'елка', '!!!']) {
        if (db.select('SELECT rowid FROM ft WHERE ft MATCH ?', [
          '"$word"*',
        ]).isNotEmpty) {
          throw StateError('Literal/token boundary mismatch');
        }
      }
      db.execute("UPDATE bodies SET body='Изменено' WHERE id=1");
      if (db
          .select("SELECT rowid FROM ft WHERE ft MATCH 'привет'")
          .isNotEmpty) {
        throw StateError('Update trigger mismatch');
      }
      db.execute('VACUUM');
      if (db.select("SELECT rowid FROM ft WHERE ft MATCH 'ИЗМЕНЕНО'").length !=
          1) {
        throw StateError('Stable rowid mismatch');
      }
      db.execute('DELETE FROM bodies');
      db.execute("INSERT INTO ft(ft,rank) VALUES('integrity-check',1)");
      if (db
          .select("SELECT rowid FROM ft WHERE ft MATCH 'изменено'")
          .isNotEmpty) {
        throw StateError('Delete trigger mismatch');
      }
      result = jsonEncode({
        'ok': true,
        'sqlite': db
            .select('SELECT sqlite_version() AS version')
            .single['version'],
      }).toJS;
    } finally {
      db.close();
    }
  } catch (error) {
    result = jsonEncode({'ok': false, 'error': error.toString()}).toJS;
  }
}
