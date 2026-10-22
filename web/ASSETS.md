# Web database assets

`sqlite3.wasm` is downloaded from the official sqlite3.dart `sqlite3-3.5.2`
release, matching `pubspec.lock`:

https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.5.2/sqlite3.wasm

SHA-256: `13d3f11d05b39ba0618a7115fb41640a5d48b6300f5d3f325f554b42bd6688a4`

`drift_worker.js` is generated from `drift_worker.dart` and locked Drift 2.34.4,
not copied from the previous application:

```sh
fvm dart compile js -O4 --no-source-maps -o build/drift_worker.js web/drift_worker.dart
cp build/drift_worker.js web/drift_worker.js
```

Regenerate/reverify both assets after a Drift/sqlite3 dependency update. Never edit
the compiled worker by hand. The generated `.deps` file is build metadata, not a
runtime asset. SQLite is public domain; Drift is MIT licensed. Worker license
notices are preserved by the Dart compiler.

Serve `.wasm` with `Content-Type: application/wasm` and use HTTPS for deployment.
For optimal cross-tab persistence configure `Cross-Origin-Opener-Policy:
same-origin` and `Cross-Origin-Embedder-Policy: require-corp` (or `credentialless`).
Without them Drift chooses a supported fallback; private browsing/storage
restrictions can prevent durable offline caching. See
https://drift.simonbinder.eu/platforms/web/ for current browser-specific details.
