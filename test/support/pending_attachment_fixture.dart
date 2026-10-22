import 'dart:async';
import 'dart:typed_data';

import 'package:collapse/core/config.dart';
import 'package:collapse/core/database/app_database.dart';
import 'package:collapse/src/data/chat/chats_repository.dart';
import 'package:collapse/src/data/media/media_repository.dart';
import 'package:collapse/src/domain/chat/chat_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/file.dart';
import 'fake_gateway.dart';

export 'package:collapse/src/domain/chat/chat_models.dart';

class PreviewDatabase extends AppDatabase {
  PreviewDatabase() : super.forTesting(NativeDatabase.memory());
  int reads = 0;
  Completer<void>? readGate;
  Completer<void>? readStarted;

  @override
  Future<Uint8List?> pendingAttachmentBytes(
    String scope,
    ChatMessage message,
    int entityIndex,
  ) async {
    reads++;
    final bytes = await super.pendingAttachmentBytes(
      scope,
      message,
      entityIndex,
    );
    readStarted?.complete();
    await readGate?.future;
    return bytes;
  }
}

class PreviewFixture {
  final db = PreviewDatabase();
  final gateway = FakeGateway();
  final cache = PreviewCache();
  late final repo = ChatsRepository(
    database: db,
    gateway: gateway,
    serverId: 'test',
  );
  late final media = MediaRepository(
    AppConfig(endpoint: Uri.parse('http://localhost:6060'), apiKey: 'test'),
    gateway,
    cache: cache,
  )..userId = 'me';

  Future<ChatMessage> queue(Object content, List<PendingUpload> uploads) async {
    await repo.start('me');
    await repo.send('usrPeer', content, uploads: uploads);
    final queued = await db.pendingOutbox('test|me');
    return db.toMessage(
      (await db.messageById('test|me', queued.last.clientId))!,
    );
  }

  Future<void> dispose() async {
    await repo.dispose();
    await media.dispose();
    await gateway.dispose();
    await db.close();
  }
}

ChatMessage previewMessage(ChatMessage message, {Object? content, int? seq}) =>
    ChatMessage(
      id: message.id,
      topicId: message.topicId,
      seq: seq ?? message.seq,
      localSeq: message.localSeq,
      senderId: message.senderId,
      createdAt: message.createdAt,
      content: content ?? message.content,
      head: message.head,
      delivery: seq == null ? message.delivery : Delivery.sent,
    );

class PreviewCache implements BaseCacheManager {
  final files = <String, FileInfo>{};
  final writes = <Uint8List>[];
  int networkReads = 0;
  Completer<void>? readGate;

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async {
    await readGate?.future;
    return files[key];
  }

  @override
  Future<File> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) async {
    writes.add(Uint8List.fromList(fileBytes));
    final file = _PreviewFile('/preview/${writes.length}.$fileExtension');
    files[key!] = FileInfo(
      file,
      FileSource.Cache,
      DateTime.now().add(maxAge),
      url,
    );
    return file;
  }

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    networkReads++;
    throw StateError('Offline preview must not request the network');
  }

  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PreviewFile implements File {
  _PreviewFile(this.path);
  @override
  final String path;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
