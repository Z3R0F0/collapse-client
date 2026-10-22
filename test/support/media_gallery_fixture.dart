import 'dart:async';

import 'package:collapse/core/config.dart';
import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/data/media/media_gallery_repository.dart';
import 'package:collapse/src/data/media/media_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:collapse/src/domain/chat/media_models.dart';
import 'package:collapse_tinode/tinode.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'fake_gateway.dart';
import 'pending_attachment_fixture.dart' show PreviewCache;

export 'package:collapse/src/domain/chat/chat_models.dart';
export 'package:collapse/src/domain/chat/media_models.dart';

const galleryScope = 'local|me';
const galleryTopic = 'usrPeer';

class GalleryGateway extends FakeGateway {
  final mediaRequests = <JsonMap>[];
  JsonMap response = {'items': <JsonMap>[]};
  Future<JsonMap> Function()? onMedia;

  @override
  Future<JsonMap> media(
    String topic, {
    String kind = 'visual',
    JsonMap? before,
    JsonMap? after,
    JsonMap? around,
    int limit = 24,
    int? snapshot,
  }) async {
    mediaRequests.add({
      'topic': topic,
      'kind': kind,
      'before': before,
      'after': after,
      'around': around,
      'limit': limit,
      'snapshot': snapshot,
    });
    return onMedia == null ? response : onMedia!();
  }
}

class GalleryMedia extends MediaRepository {
  GalleryMedia(GalleryGateway gateway)
    : super(
        AppConfig(endpoint: Uri.parse('http://localhost:6060'), apiKey: 'test'),
        gateway,
        cache: PreviewCache(),
      );
  final requested = <String>[];
  @override
  Future<Uint8List> bytes(String ref) {
    requested.add(ref);
    return super.bytes(ref);
  }
}

class GalleryFixture {
  bool _disposed = false;
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final gateway = GalleryGateway();
  late final chats = ChatsRepository(
    database: db,
    gateway: gateway,
    serverId: 'local',
  );
  late final media = GalleryMedia(gateway)..userId = 'me';
  late final gallery = MediaGalleryRepository(chats, media);

  Future<void> start() async {
    await chats.start('me'); // Offline: no unrelated account-refresh history.
    await db.mergeTopic(galleryScope, galleryTopic, {
      'seq': 200,
      'read': 7,
      'recv': 9,
    });
    gateway.ready = true;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await chats.dispose();
    await media.dispose();
    await gateway.dispose();
    await db.close();
  }
}

JsonMap galleryPacket(
  int seq, {
  int key = 0,
  String type = 'IM',
  String from = 'peer',
  String? clientId,
  JsonMap? data,
  bool inline = false,
}) => {
  'seq': seq,
  'key': key,
  'type': type,
  'from': from,
  'clientId': ?clientId,
  'ts': DateTime.utc(2026, 9, 22).add(Duration(seconds: seq)).toIso8601String(),
  'data': data ?? {'ref': '/v0/file/s/image-$seq-$key', 'mime': 'image/png'},
  'inline': inline,
};

JsonMap galleryPhoto({String ref = '/v0/file/s/image', String? value}) => {
  'txt': ' ',
  'fmt': [
    {'at': 0, 'len': 1, 'key': 1},
  ],
  'ent': [
    null,
    {
      'tp': 'IM',
      'data': {'ref': ref, 'mime': 'image/png', 'val': ?value},
    },
  ],
};

ChatMessage galleryMessage(
  int seq,
  Object content, {
  String? id,
  String sender = 'peer',
}) => ChatMessage(
  id: id ?? '$galleryTopic:$seq',
  topicId: galleryTopic,
  seq: seq,
  localSeq: seq < 0 ? seq.abs() : 0,
  senderId: sender,
  createdAt: DateTime.utc(2026, 9, 22).add(Duration(seconds: seq.abs())),
  content: content,
);

MediaItem galleryItem(int seq, {int key = 0}) => MediaItem.fromJson(
  galleryTopic,
  {...galleryPacket(seq, key: key), 'clientId': '$galleryTopic:$seq'},
);

/// Exact pre-atlas schema, including original v2 FTS/index definitions.
class GallerySchemaV2 extends AppDatabase {
  GallerySchemaV2(super.executor) : super.forTesting();
  @override
  int get schemaVersion => 2;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await super.migration.onCreate(m);
      await m.deleteTable('media_entries');
    },
  );
}
