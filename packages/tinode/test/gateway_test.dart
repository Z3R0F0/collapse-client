import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collapse_tinode/tinode.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  late _Server server;
  late TinodeGateway gateway;

  setUp(() async {
    server = await _Server.start();
    gateway = TinodeGateway(endpoint: server.uri, apiKey: 'test-api-key');
  });
  tearDown(() async {
    await gateway.dispose();
    await server.close();
  });

  test('media pages correlate independently and never emit history data',
      () async {
    final requests = <JsonMap>[];
    server.handle = (socket, kind, packet) {
      expect(kind, 'get');
      expect(packet['what'], 'media');
      requests.add(packet);
      if (requests.length != 2) return;
      for (final request in requests.reversed) {
        socket.add(jsonEncode({
          'meta': {
            'id': request['id'],
            'topic': request['topic'],
            'media': {
              'items': <Object>[],
              'hasOlder': false,
              'hasNewer': false,
              'snapshot': (request['media'] as Map)['snapshot'] ?? 80,
              'delId': 3,
            },
          },
        }));
      }
    };
    await gateway.connect();
    final events = <TinodeEvent>[];
    final listener = gateway.events.listen(events.add);
    final pages = await Future.wait([
      gateway.media('grpA', before: {'seq': 50, 'key': 2}, snapshot: 70),
      gateway.media('grpA', kind: 'audio', around: {'seq': 60, 'key': 0}),
    ]);
    expect(pages.map((page) => page['snapshot']), [70, 80]);
    expect((requests.first['media'] as Map)['limit'], 24);
    expect((requests.first['media'] as Map)['before'], {'seq': 50, 'key': 2});
    expect(events.where((event) => event.kind == 'data'), isEmpty);
    await listener.cancel();
  });

  test('media ACL errors remain correlated typed failures', () async {
    server.handle =
        (socket, kind, packet) => server.ctrl(socket, packet, code: 403);
    await gateway.connect();
    await expectLater(
        gateway.media('grpPrivate'),
        throwsA(
            isA<TinodeException>().having((error) => error.code, 'code', 403)));
  });

  test('invalid atlas cursors and unsupported categories never reach transport',
      () async {
    for (final invalid in <Future<JsonMap> Function()>[
      () => gateway.media('grpA', kind: 'everything'),
      () => gateway.media('grpA', limit: 41),
      () => gateway.media('grpA', limit: 0),
      () => gateway.media('grpA', before: {'seq': 0, 'key': 0}),
      () => gateway.media('grpA', after: {'seq': 1, 'key': -1}),
      () => gateway.media('grpA', around: {'seq': 1.5, 'key': 0}),
      () => gateway.media('grpA', snapshot: -1),
      () => gateway.media('grpA',
          before: {'seq': 2, 'key': 0}, after: {'seq': 1, 'key': 0}),
    ]) {
      await expectLater(invalid(), throwsArgumentError);
    }
    expect(server.packets, isEmpty);
  });

  test('single-flight liveness probe preserves the healthy session', () async {
    await gateway.connect();
    gateway.userId = 'usrAlice';
    gateway.token = 'synthetic-token';
    await Future.wait([gateway.probe(), gateway.probe(), gateway.probe()]);
    expect(server.probes, 1);
    expect(gateway.connected, isTrue);
    expect(gateway.userId, 'usrAlice');
    expect(gateway.token, 'synthetic-token');
    expect(server.packets.where((packet) => packet.$1 == 'hi'), hasLength(1));
  });

  test('half-open socket probe times out and closes the stale session',
      () async {
    await gateway.dispose();
    gateway = TinodeGateway(
      endpoint: server.uri,
      apiKey: 'test-api-key',
      timeout: const Duration(milliseconds: 100),
    );
    server.onProbe = (_) {};
    await gateway.connect();
    gateway.userId = 'usrAlice';
    await Future.wait([
      expectLater(gateway.probe(), throwsA(isA<TimeoutException>())),
      expectLater(gateway.probe(), throwsA(isA<TimeoutException>())),
    ]);
    expect(server.probes, 1);
    expect(gateway.connected, isFalse);
    expect(gateway.userId, isNull);
  });

  test('disconnect rejects a pending probe; replacement socket probes anew',
      () async {
    final started = Completer<void>();
    server.onProbe = (_) => started.complete();
    await gateway.connect();
    final failed =
        expectLater(gateway.probe(), throwsA(isA<TinodeException>()));
    await started.future;
    await gateway.disconnect();
    await failed;
    server.onProbe = null;
    await gateway.connect();
    await gateway.probe();
    expect(gateway.connected, isTrue);
    expect(server.probes, 2);
  });

  test('probing a disconnected gateway returns a typed connection error',
      () async {
    await expectLater(gateway.probe(), throwsA(isA<TinodeException>()));
  });

  test('WebSocket connector receives no fragment, including an empty one',
      () async {
    for (final endpoint in [
      server.uri,
      server.uri.replace(fragment: ''),
      server.uri.replace(fragment: 'client-state')
    ]) {
      final client = TinodeGateway(
          endpoint: endpoint,
          apiKey: 'test-api-key',
          connector: (uri) {
            expect(uri.hasFragment, isFalse);
            expect(uri.scheme, 'ws');
            expect(uri.authority, server.uri.authority);
            expect(uri.path, '/v0/channels');
            expect(uri.queryParameters, {'apikey': 'test-api-key'});
            return WebSocketChannel.connect(uri);
          });
      try {
        expect(client.serverUri.hasFragment, isFalse);
        await client.connect();
        expect(client.connected, isTrue);
      } finally {
        await client.dispose();
      }
    }
  });

  test('TLS endpoint normalization preserves backend origin without fragments',
      () async {
    final client = TinodeGateway(
        endpoint: Uri.parse('wss://chat.test:8443/v0/channels#'),
        apiKey: 'test-api-key');
    expect(client.serverUri.scheme, 'https');
    expect(client.serverUri.authority, 'chat.test:8443');
    expect(client.serverUri.hasFragment, isFalse);
    expect(client.resolveFile('file.png').toString(),
        'https://chat.test:8443/v0/file/s/file.png');
    await client.dispose();
  });

  test('single-flight handshake and attachment; reconnect reattaches',
      () async {
    server.handle = (socket, kind, packet) => server.ctrl(socket, packet);
    await Future.wait([gateway.connect(), gateway.connect()]).timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw StateError('connect'));
    await Future.wait([gateway.attach('grpA'), gateway.attach('grpA')]).timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw StateError('attach'));
    await gateway.attach('grpA').timeout(const Duration(seconds: 3),
        onTimeout: () => throw StateError('cached attach'));
    expect(server.packets.where((p) => p.$1 == 'hi').length, 1);
    expect(server.packets.where((p) => p.$1 == 'sub').length, 1);
    await gateway.disconnect().timeout(const Duration(seconds: 3),
        onTimeout: () => throw StateError('disconnect'));
    expect(gateway.connected, isFalse);
    await gateway.connect().timeout(const Duration(seconds: 3),
        onTimeout: () => throw StateError('reconnect'));
    await gateway.attach('grpA').timeout(const Duration(seconds: 3),
        onTimeout: () => throw StateError('reattach'));
    expect(server.packets.where((p) => p.$1 == 'sub').length, 2);
  });

  test('basic auth preserves UTF-8 and records server-issued identity',
      () async {
    server.handle = (socket, kind, packet) {
      expect(kind, 'login');
      expect(utf8.decode(base64Decode(packet['secret'] as String)),
          'alice:пароль');
      server.ctrl(socket, packet,
          params: {'user': 'usrAlice', 'token': 'synthetic-token'});
    };
    await gateway.connect();
    await gateway.loginBasic('alice', 'пароль');
    expect(gateway.userId, 'usrAlice');
    expect(gateway.token, 'synthetic-token');
  });

  test('credential challenge is not an authenticated session', () async {
    server.handle = (socket, kind, packet) =>
        server.ctrl(socket, packet, code: 300, params: {
          'user': 'usrAlice',
          'cred': ['email']
        });
    await gateway.connect();
    final ctrl = await gateway
        .createAccountBasic('alice', 'password', public: {'fn': 'Alice'});
    expect(ctrl['code'], 300);
    expect(gateway.userId, isNull);
  });

  test('device registration uses standard hi and null uses deletion marker',
      () async {
    await gateway.connect();
    gateway.userId = 'usrTest';
    await gateway.setDeviceToken('synthetic-device');
    await gateway.setDeviceToken(null);
    final hi = server.packets.where((p) => p.$1 == 'hi').toList();
    expect(hi[1].$2['dev'], 'synthetic-device');
    expect(hi[2].$2['dev'], '\u2421');
  });

  test('metadata completes on meta; all packet kinds preserve topic', () async {
    server.handle = (socket, kind, packet) {
      socket.add(jsonEncode({
        'pres': {'topic': 'me', 'src': 'grpA', 'what': 'msg', 'seq': 3}
      }));
      socket.add(jsonEncode({
        'info': {'topic': 'grpA', 'what': 'read', 'seq': 2}
      }));
      socket.add(jsonEncode({
        'meta': {
          'id': packet['id'],
          'topic': 'me',
          'sub': [
            {'topic': 'grpA', 'seq': 3, 'read': 1, 'recv': 2}
          ]
        }
      }));
    };
    final events = <TinodeEvent>[];
    final sub = gateway.events.listen(events.add);
    await gateway.connect();
    final topics = await gateway.subscriptions();
    expect(topics.single['seq'], 3);
    expect(events.firstWhere((e) => e.kind == 'pres').topic, 'me');
    expect(events.firstWhere((e) => e.kind == 'info').topic, 'grpA');
    await sub.cancel();
  });

  test('history awaits matching data completion, filters range, emits globally',
      () async {
    server.handle = (socket, kind, packet) {
      expect(packet['data'], {'since': 8, 'before': 11, 'limit': 3});
      server.ctrl(socket, packet, params: {'what': 'sub'});
      for (final seq in [11, 10, 9, 9, 8, 7]) {
        socket.add(jsonEncode({
          'data': {'topic': 'grpA', 'seq': seq, 'content': '$seq'}
        }));
      }
      socket.add(jsonEncode({
        'data': {'topic': 'grpB', 'seq': 10}
      }));
      server.ctrl(socket, packet,
          code: 208, params: {'what': 'data', 'count': 3});
    };
    final events = <TinodeEvent>[];
    final sub = gateway.events.listen(events.add);
    await gateway.connect();
    final history =
        await gateway.history('grpA', since: 8, before: 11, limit: 3);
    expect(history.map((m) => m['seq']), [10, 9, 8]);
    expect(events.where((e) => e.kind == 'data').length, 7);
    await sub.cancel();
  });

  test('same-topic history requests are serialized', () async {
    final firstReceived = Completer<void>();
    JsonMap? first;
    WebSocket? peer;
    var requestCount = 0;
    server.handle = (socket, kind, packet) {
      peer = socket;
      requestCount++;
      if (requestCount == 1) {
        first = packet;
        firstReceived.complete();
      } else {
        server.ctrl(socket, packet,
            code: 208, params: {'what': 'data', 'count': 0});
      }
    };
    await gateway.connect();
    final one = gateway.history('grpA', before: 10);
    final two = gateway.history('grpA', before: 5);
    await firstReceived.future;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(requestCount, 1);
    server.ctrl(peer!, first!, code: 208, params: {'what': 'data', 'count': 0});
    expect(await one, isEmpty);
    expect(await two, isEmpty);
    expect(requestCount, 2);
  });

  test('receipt notes from distinct topics never suppress each other',
      () async {
    final received = Completer<void>();
    final topics = <String>[];
    server.handle = (socket, kind, packet) {
      if (kind == 'note') {
        topics.add(packet['topic'] as String);
        if (topics.length == 2) received.complete();
      }
    };
    await gateway.connect();
    gateway.note('grpA', 'read', seq: 300);
    gateway.note('grpB', 'read', seq: 2);
    await received.future;
    expect(topics, ['grpA', 'grpB']);
  });

  test('publish preserves stable client id, reply, Drafty and ACK', () async {
    server.handle = (socket, kind, packet) {
      expect(packet['head'],
          {'mime': DraftyCodec.mime, 'reply': '3', 'x-client-id': 'stable'});
      expect(packet['content'], {'txt': 'hello'});
      server.ctrl(socket, packet, code: 202, params: {'seq': 5});
    };
    await gateway.connect();
    final ctrl = await gateway.publish('grpA',
        content: DraftyCodec.text('hello'),
        head: {'mime': DraftyCodec.mime, 'reply': '3'},
        clientId: 'stable');
    expect((ctrl['params'] as Map)['seq'], 5);
    expect(ctrl['ts'], '2026-01-01T00:00:00Z');
  });

  test('publish links uploaded files using top-level extra, preserving head',
      () async {
    await gateway.connect();
    server.handle = (socket, kind, packet) => server.ctrl(socket, packet);
    final attachments = [
      '/v0/file/s/first.png',
      '${server.uri}/v0/file/s/first.png?ignored=1#fragment',
      'second.png',
      'https://external.test/v0/file/s/other.png',
      '/unrelated/path',
    ];
    final head = {'mime': DraftyCodec.mime, 'attachments': attachments};
    await gateway.publish('grpA', content: {'txt': 'media'}, head: head);
    expect(server.envelopes.last['extra'], {
      'attachments': ['/v0/file/s/first.png', '/v0/file/s/second.png']
    });
    expect((server.envelopes.last['pub'] as Map)['head'], head);
    expect(head['attachments'], attachments);
    await gateway.publish('grpA', content: {'txt': 'text only'});
    expect(server.envelopes.last.containsKey('extra'), isFalse);
  });

  test('metadata GC attachments are envelope-only and optional', () async {
    await gateway.connect();
    server.handle = (socket, kind, packet) => server.ctrl(socket, packet);
    final metadata = {
      'desc': {
        'public': {
          'fn': 'Updated name',
          'photo': {'ref': '/v0/file/s/avatar.png'}
        }
      }
    };
    await gateway
        .setMeta('me', metadata, attachments: ['/v0/file/s/avatar.png']);
    expect(server.envelopes.last['extra'], {
      'attachments': ['/v0/file/s/avatar.png']
    });
    expect((server.envelopes.last['set'] as Map)['desc'], metadata['desc']);
    expect((server.envelopes.last['set'] as Map).containsKey('extra'), isFalse);
    await gateway.setMeta('me', metadata);
    expect(server.envelopes.last.containsKey('extra'), isFalse);
  });

  test('only same-origin managed files become GC attachments', () async {
    await gateway.connect();
    server.handle = (socket, kind, packet) => server.ctrl(socket, packet);
    await gateway.setMeta('me', {
      'desc': {
        'public': {'fn': 'Name'}
      }
    }, attachments: [
      '//external.test/v0/file/s/avatar.png',
      'data:image/png;base64,fixture',
      '/v0/file/s/',
      '/outside/file.png',
      '${server.uri.scheme}://user@${server.uri.authority}/v0/file/s/file.png',
    ]);
    expect(server.envelopes.last.containsKey('extra'), isFalse);
  });

  test('deletion query serializes del and returns ranges', () async {
    server.handle = (socket, kind, packet) {
      expect(packet['del'], {'since': 4});
      socket.add(jsonEncode({
        'meta': {
          'topic': 'grpA',
          'id': packet['id'],
          'del': {
            'clear': 8,
            'delseq': [
              {'low': 3, 'hi': 5}
            ]
          }
        }
      }));
    };
    await gateway.connect();
    final deleted = await gateway.deletions('grpA', since: 4);
    expect(deleted['clear'], 8);
  });

  test('server errors are typed and pending requests fail on disconnect',
      () async {
    server.handle =
        (socket, kind, packet) => server.ctrl(socket, packet, code: 403);
    await gateway.connect();
    await expectLater(gateway.history('grpA'),
        throwsA(isA<TinodeException>().having((e) => e.code, 'code', 403)));
    final received = Completer<void>();
    server.handle = (socket, kind, packet) => received.complete();
    final pending = gateway.description('grpA');
    final assertion = expectLater(pending, throwsA(isA<TinodeException>()));
    await received.future;
    await gateway.disconnect();
    await assertion;
  });

  test('malformed frames do not prevent subsequent metadata', () async {
    server.handle = (socket, kind, packet) {
      socket.add('{broken');
      socket.add(jsonEncode({
        'meta': {
          'id': packet['id'],
          'topic': 'grpA',
          'desc': {'seq': 5}
        }
      }));
    };
    await gateway.connect();
    expect((await gateway.description('grpA'))['seq'], 5);
  });

  test('upload uses own-origin credentials and normalized Tinode references',
      () async {
    final uploader = TinodeGateway(
        endpoint: Uri.parse('https://example.test'),
        apiKey: 'key',
        httpClient: MockClient((request) async {
          expect(request.url.toString(), 'https://example.test/v0/file/u/');
          expect(request.headers['authorization'], 'token synthetic-token');
          expect(request.headers['x-tinode-apikey'], 'key');
          expect(request.headers['content-type'],
              startsWith('multipart/form-data;'));
          return http.Response(
              jsonEncode({
                'ctrl': {
                  'code': 200,
                  'params': {'url': 'file.png'}
                }
              }),
              200);
        }));
    uploader.token = 'synthetic-token';
    expect(
        await uploader.upload(Uint8List.fromList([1, 2]),
            name: 'file.png', mime: 'image/png'),
        '/v0/file/s/file.png');
    await uploader.dispose();
  });

  test('upload redirects never leak credentials to another origin', () async {
    var requests = 0;
    final uploader = TinodeGateway(
        endpoint: Uri.parse('https://example.test'),
        apiKey: 'key',
        httpClient: MockClient((request) async {
          requests++;
          return http.Response('', 307,
              headers: {'location': 'https://external.test/upload'});
        }));
    uploader.token = 'synthetic-token';
    await expectLater(
        uploader.upload(Uint8List(1), name: 'file', mime: 'image/png'),
        throwsA(isA<TinodeException>()));
    expect(requests, 1);
    expect(() => uploader.resolveFile('//external.test/file'),
        throwsA(isA<TinodeException>()));
    await uploader.dispose();
  });
}

class _Server {
  _Server(this.server);
  final HttpServer server;
  final peers = <WebSocket>[];
  final packets = <(String, JsonMap)>[];
  final envelopes = <JsonMap>[];
  void Function(WebSocket, String, JsonMap)? handle;
  void Function(WebSocket)? onProbe;
  int probes = 0;
  Uri get uri => Uri.parse('http://127.0.0.1:${server.port}');

  static Future<_Server> start() async {
    final result =
        _Server(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    result.server.listen((request) async {
      final peer = await WebSocketTransformer.upgrade(request);
      result.peers.add(peer);
      peer.listen((frame) {
        if (frame == '1') {
          result.probes++;
          if (result.onProbe != null) {
            result.onProbe!(peer);
          } else {
            peer.add('0');
          }
          return;
        }
        final envelope = jsonDecode(frame as String) as Map;
        result.envelopes.add(Map<String, dynamic>.from(envelope));
        final kind =
            envelope.keys.where((key) => key != 'extra').single as String;
        final packet = Map<String, dynamic>.from(envelope[kind] as Map);
        result.packets.add((kind, packet));
        if (kind == 'hi') {
          result.ctrl(peer, packet);
        } else {
          result.handle?.call(peer, kind, packet);
        }
      });
    });
    return result;
  }

  void ctrl(WebSocket peer, JsonMap packet,
      {int code = 200, JsonMap params = const {}}) {
    peer.add(jsonEncode({
      'ctrl': {
        'id': packet['id'],
        'topic': packet['topic'],
        'code': code,
        'text': 'test response',
        'params': params,
        'ts': '2026-01-01T00:00:00Z'
      }
    }));
  }

  Future<void> close() async {
    for (final peer in peers) {
      await peer.close();
    }
    await server.close(force: true);
  }
}
