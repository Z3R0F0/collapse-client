import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collapse_tinode/tinode.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  late _UploadClient client;
  late TinodeGateway gateway;
  setUp(() {
    client = _UploadClient();
    gateway = TinodeGateway(
      endpoint: Uri.parse('https://example.test'),
      apiKey: 'test',
      httpClient: client,
      timeout: const Duration(milliseconds: 80),
    )..token = 'synthetic-token';
  });
  tearDown(() async {
    await gateway.dispose();
    await client.finish();
  });

  Future<String> upload() => gateway.upload(
        Uint8List.fromList([1, 2]),
        name: 'photo.png',
        mime: 'image/png',
      );

  test('upload header timeout aborts HTTP and retains TimeoutException',
      () async {
    await expectLater(upload(), throwsA(isA<TimeoutException>()));
    await client.aborted.future.timeout(const Duration(seconds: 1));
    expect(client.aborts, 1);
    expect(client.closed, isFalse);
  });

  test('upload response timeout aborts HTTP and retains TimeoutException',
      () async {
    final result = upload();
    final failed = expectLater(result, throwsA(isA<TimeoutException>()));
    await client.started.future;
    client.headers.complete(http.StreamedResponse(client.body.stream, 200));
    await failed;
    await client.aborted.future.timeout(const Duration(seconds: 1));
    expect(client.aborts, 1);
  });

  for (final honorsAbort in [true, false]) {
    test('disconnect rejects a late upload (client honors abort: $honorsAbort)',
        () async {
      client.honorsAbort = honorsAbort;
      final result = upload();
      final failed = expectLater(result, throwsA(isA<TinodeException>()));
      await client.started.future;
      client.headers.complete(http.StreamedResponse(client.body.stream, 200));
      await gateway.disconnect();
      // A client ignoring aborts must still not return a stale account's URL.
      if (!client.body.isClosed) {
        client.body.add(utf8.encode(jsonEncode({
          'ctrl': {
            'code': 200,
            'params': {'url': 'old-upload.png'}
          }
        })));
        unawaited(client.body.close());
      }
      await failed;
      expect(client.aborts, 1);
    });
  }
}

class _UploadClient extends http.BaseClient {
  final started = Completer<void>();
  final aborted = Completer<void>();
  final headers = Completer<http.StreamedResponse>();
  final body = StreamController<List<int>>();
  int aborts = 0;
  bool closed = false;
  bool honorsAbort = true;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    started.complete();
    if (request is http.Abortable) {
      request.abortTrigger?.then((_) {
        aborts++;
        aborted.complete();
        if (!honorsAbort) return;
        if (!headers.isCompleted) {
          headers.completeError(http.RequestAbortedException(request.url));
        } else if (!body.isClosed) {
          body.addError(http.RequestAbortedException(request.url));
          unawaited(body.close());
        }
      });
    }
    return headers.future;
  }

  Future<void> finish() async {
    if (!headers.isCompleted) {
      headers.complete(http.StreamedResponse(const Stream.empty(), 200));
      await body.stream.listen((_) {}).cancel();
    }
    if (!body.isClosed) unawaited(body.close());
  }

  @override
  void close() => closed = true;
}
