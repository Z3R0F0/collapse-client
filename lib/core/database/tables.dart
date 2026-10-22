part of 'app_database.dart';

@DataClassName('TopicRow')
class Topics extends Table {
  TextColumn get scope => text()();
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get avatarRef => text().nullable()();
  BoolColumn get online => boolean().withDefault(const Constant(false))();
  BoolColumn get isGroup => boolean().withDefault(const Constant(false))();
  IntColumn get serverSeq => integer().withDefault(const Constant(0))();
  IntColumn get readSeq => integer().withDefault(const Constant(0))();
  IntColumn get recvSeq => integer().withDefault(const Constant(0))();
  IntColumn get peerReadSeq => integer().withDefault(const Constant(0))();
  IntColumn get peerRecvSeq => integer().withDefault(const Constant(0))();
  IntColumn get lastMessageSeq => integer().withDefault(const Constant(0))();
  IntColumn get lastMessageAt => integer().nullable()();
  TextColumn get lastPreview => text().withDefault(const Constant(''))();
  TextColumn get draft => text().withDefault(const Constant(''))();
  IntColumn get deletionId => integer().withDefault(const Constant(0))();
  TextColumn get coverage => text().withDefault(const Constant('[]'))();
  TextColumn get deletedRanges => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {scope, id};
}

@DataClassName('MessageRow')
@TableIndex(name: 'messages_client_id', columns: {#scope, #clientId})
class Messages extends Table {
  TextColumn get scope => text()();
  TextColumn get topicId => text()();
  IntColumn get seq => integer()();
  TextColumn get clientId => text()();
  IntColumn get localSeq => integer().withDefault(const Constant(0))();
  TextColumn get senderId => text()();
  IntColumn get createdAtMs => integer()();
  TextColumn get content => text()();
  TextColumn get head => text().withDefault(const Constant('{}'))();
  IntColumn get delivery => integer().withDefault(const Constant(2))();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {scope, topicId, seq};
}

/// Rebuildable visible text, not a second message or wire representation.
@DataClassName('MessageSearchRow')
class MessageSearch extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get scope => text()();
  TextColumn get topicId => text()();
  IntColumn get seq => integer()();
  TextColumn get body => text()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {scope, topicId, seq},
  ];
}

@DataClassName('OutboxRow')
class Outbox extends Table {
  TextColumn get scope => text()();
  TextColumn get clientId => text()();
  TextColumn get topicId => text()();
  IntColumn get localSeq => integer()();
  IntColumn get afterSeq => integer().withDefault(const Constant(0))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get nextRetryAt => integer().withDefault(const Constant(0))();
  BoolColumn get ambiguous => boolean().withDefault(const Constant(false))();
  TextColumn get error => text().nullable()();

  @override
  Set<Column> get primaryKey => {scope, clientId};
}

@DataClassName('OutboxAttachmentRow')
class OutboxAttachments extends Table {
  TextColumn get scope => text()();
  TextColumn get clientId => text()();
  IntColumn get entityIndex => integer()();
  BlobColumn get bytes => blob()();
  TextColumn get name => text()();
  TextColumn get mime => text()();
  TextColumn get remoteRef => text().nullable()();

  @override
  Set<Column> get primaryKey => {scope, clientId, entityIndex};
}

/// Lightweight gallery metadata. No file bytes, chat coverage or read state.
@DataClassName('MediaEntryRow')
@TableIndex(
  name: 'media_category',
  columns: {#scope, #topicId, #type, #seq, #entityIndex},
)
class MediaEntries extends Table {
  TextColumn get scope => text()();
  TextColumn get topicId => text()();
  IntColumn get seq => integer()();
  IntColumn get entityIndex => integer()();
  TextColumn get clientId => text()();
  TextColumn get type => text()();
  TextColumn get senderId => text()();
  IntColumn get createdAtMs => integer()();
  TextColumn get data => text()();
  BoolColumn get isInline => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {scope, topicId, seq, entityIndex};
}
