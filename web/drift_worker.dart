import 'package:drift/wasm.dart';

// Regenerate the JS worker after changes to the locked drift/sqlite3 versions.
void main() => WasmDatabase.workerMainForOpen();
