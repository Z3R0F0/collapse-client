import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collapse_tinode/tinode.dart';

/// Explicit local integration test. Creates labelled throwaway users and a group.
/// Usage: dart run tool/smoke.dart /path/to/backend/.local/client.json
/// The config contains credentials and is never printed or copied into sources.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    throw ArgumentError('Supply the local backend client.json path');
  }
  final config = jsonDecode(await File(arguments.single).readAsString()) as Map;
  final host = config['TINODE_HOST'].toString();
  final scheme = config['TINODE_TLS'] == true || config['TINODE_TLS'] == 'true'
      ? 'https'
      : 'http';
  final endpoint = Uri.parse(host.contains('://') ? host : '$scheme://$host');
  if (!['localhost', '127.0.0.1', '::1'].contains(endpoint.host)) {
    throw ArgumentError('This fixture-creating smoke test is local-only');
  }
  final key = config['TINODE_API_KEY'] as String;
  final alice = TinodeGateway(endpoint: endpoint, apiKey: key);
  final bob = TinodeGateway(endpoint: endpoint, apiKey: key);
  final suffix = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final password = 'smoke-local-$suffix';
  try {
    await Future.wait([alice.connect(), bob.connect()]);
    await alice.createAccountBasic('c${suffix}a', password,
        public: {'fn': 'Collapse smoke Alice'});
    await bob.createAccountBasic('c${suffix}b', password,
        public: {'fn': 'Collapse smoke Bob'});
    _check(
        alice.userId != null && bob.userId != null, 'account authentication');
    await Future.wait([alice.attach('me'), bob.attach('me')]);
    final created = await alice.attach('new', set: {
      'desc': {
        'public': {'fn': 'Collapse smoke fixture'},
        'defacs': {'auth': 'JRWPS', 'anon': 'N'},
      }
    });
    final topic = created['topic'] as String;
    await bob.attach(topic);
    for (var i = 1; i <= 3; i++) {
      final ack = await alice.publish(topic,
          content: DraftyCodec.text('message $i'),
          head: {'mime': DraftyCodec.mime},
          clientId: '$suffix-$i');
      _check((ack['params'] as Map)['seq'] == i, 'publish ACK sequence');
    }
    final page = await bob.history(topic, since: 1, before: 3, limit: 2);
    _check(page.map((message) => message['seq']).join(',') == '2,1',
        'bounded descending history');
    _check((page.first['head'] as Map)['x-client-id'] == '$suffix-2',
        'optimistic identity round-trip');
    final read = alice.events.firstWhere((event) =>
        event.kind == 'info' &&
        event.topic == topic &&
        event.payload['what'] == 'read');
    bob.note(topic, 'recv', seq: 3);
    bob.note(topic, 'read', seq: 3);
    _check((await read.timeout(const Duration(seconds: 5))).payload['seq'] == 3,
        'read receipt');
    final subscriptions = await bob.subscriptions();
    final summary = subscriptions.firstWhere((sub) => sub['topic'] == topic);
    _check(summary['seq'] == 3 && summary['read'] == 3,
        'me sequence/read summary');
    final file = await alice.upload(
        Uint8List.fromList(utf8.encode('Collapse smoke fixture')),
        name: 'fixture.txt',
        mime: 'text/plain');
    _check(
        alice.resolveFile(file).path.startsWith('/v0/file/s/'), 'file upload');
    await bob.deleteMessages(
        topic,
        [
          {'low': 2}
        ],
        hard: false);
    final deletions = await bob.deletions(topic);
    _check(
        (deletions['delseq'] as List?)?.isNotEmpty == true, 'deletion history');
    final token = alice.token!;
    await alice.disconnect();
    await alice.connect();
    await alice.loginToken(token);
    await alice.attach('me');
    _check((await alice.subscriptions()).any((sub) => sub['topic'] == topic),
        'session restore');
    await alice.attach(topic);
    _check((await alice.history(topic, limit: 1)).single['seq'] == 3,
        'history after reconnect');
    stdout.writeln(
        'PASS: auth, group, publish, history, receipts, summaries, upload, deletions, reconnect.');
    stdout.writeln(
        'Created isolated local smoke-test users and a labelled group.');
  } finally {
    await Future.wait([alice.dispose(), bob.dispose()]);
  }
}

void _check(bool result, String operation) {
  if (!result) throw StateError('Smoke assertion failed: $operation');
}
