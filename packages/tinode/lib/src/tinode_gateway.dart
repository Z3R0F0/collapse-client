import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'tinode_types.dart';

export 'tinode_types.dart';

part 'gateway_connection.dart';
part 'gateway_requests.dart';
part 'gateway_auth.dart';
part 'gateway_topics.dart';
part 'gateway_history.dart';
part 'gateway_media.dart';
part 'gateway_upload.dart';

/// JSON protocol adapter, not a second message cache or an application SDK.
/// Repositories own reconnection, authentication, persistence and attachment policy.
class TinodeGateway {
  TinodeGateway({
    required this.endpoint,
    required this.apiKey,
    WebSocketChannel Function(Uri)? connector,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 20),
  })  : _connector = connector ?? WebSocketChannel.connect,
        _http = httpClient ?? http.Client() {
    if (!['http', 'https', 'ws', 'wss'].contains(endpoint.scheme) ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty) {
      throw ArgumentError('Expected an HTTP(S) or WS(S) Tinode endpoint');
    }
  }

  final Uri endpoint;
  final String apiKey;
  final Duration timeout;
  final WebSocketChannel Function(Uri) _connector;
  final http.Client _http;
  final _events = StreamController<TinodeEvent>.broadcast(sync: true);
  final _pending = <String, _Pending>{};
  final _attached = <String>{};
  final _attaching = <String, Future<JsonMap>>{};
  final _historyQueues = <String, Future<void>>{};
  final _uploads = <Completer<void>>{};
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _subscription;
  Future<void>? _connecting;
  Future<void>? _probing;
  Completer<void>? _probeResponse;
  int _epoch = 0;
  int _requestId = 0;
  bool _ready = false;
  bool _disposed = false;

  Stream<TinodeEvent> get events => _events.stream;
  bool get connected => _ready;
  String? userId;
  String? token;

  Uri get serverUri => endpoint
      .replace(
        scheme: ['https', 'wss'].contains(endpoint.scheme) ? 'https' : 'http',
        path: '/',
        query: '',
      )
      .removeFragment();

  Future<void> connect() {
    if (_disposed) return Future.error(StateError('Gateway is disposed'));
    if (_ready) return Future.value();
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<void> disconnect() => _disconnect();
  Future<void> dispose() => _dispose();

  /// Verify a seemingly open socket with Tinode's standard network probe.
  Future<void> probe() {
    if (_probing != null) return _probing!;
    final task = _probeConnection();
    _probing = task;
    return task.whenComplete(() {
      if (identical(_probing, task)) _probing = null;
    });
  }

  Future<JsonMap> loginBasic(String username, String password) =>
      _loginBasic(username, password);
  Future<JsonMap> loginToken(String value) => _loginToken(value);
  Future<JsonMap> createAccountBasic(String username, String password,
          {required JsonMap public}) =>
      _createAccountBasic(username, password, public: public);

  /// Standard Tinode device registration; U+2421 clears this session's device.
  Future<void> setDeviceToken(String? value) => _setDeviceToken(value);

  Future<JsonMap> attach(String topic, {JsonMap? set}) =>
      _attach(topic, set: set);
  Future<JsonMap> leave(String topic, {bool unsubscribe = false}) =>
      _leave(topic, unsubscribe: unsubscribe);
  Future<List<JsonMap>> subscriptions({String topic = 'me'}) =>
      _subscriptions(topic: topic);
  Future<JsonMap> description(String topic) => _description(topic);

  /// Serialized per topic; completes on Tinode's history-completion packet.
  Future<List<JsonMap>> history(String topic,
          {int? since, int? before, int limit = 40}) =>
      _history(topic, since: since, before: before, limit: limit);

  /// Collapse's indexed atlas extension; independent of ordinary chat history.
  Future<JsonMap> media(String topic,
          {String kind = 'visual',
          JsonMap? before,
          JsonMap? after,
          JsonMap? around,
          int limit = 24,
          int? snapshot}) =>
      _media(topic,
          kind: kind,
          before: before,
          after: after,
          around: around,
          limit: limit,
          snapshot: snapshot);
  Future<JsonMap> deletions(String topic, {int since = 0}) =>
      _deletions(topic, since: since);
  Future<JsonMap> setMeta(String topic, JsonMap set,
          {List<String> attachments = const []}) =>
      _setMeta(topic, set, attachments: attachments);
  Future<JsonMap> publish(String topic,
          {required Object content,
          JsonMap head = const {},
          String? clientId}) =>
      _publish(topic, content: content, head: head, clientId: clientId);
  void note(String topic, String what, {int? seq}) =>
      _note(topic, what, seq: seq);
  Future<JsonMap> deleteMessages(String topic, List<Map<String, int>> ranges,
          {bool hard = false}) =>
      _deleteMessages(topic, ranges, hard: hard);

  /// Resolve relative refs without forwarding credentials off-origin.
  Uri resolveFile(String ref) => _resolveFile(ref);
  Future<String> upload(Uint8List bytes,
          {required String name, required String mime}) =>
      _upload(bytes, name: name, mime: mime);
}
