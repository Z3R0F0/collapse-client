// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TopicsTable extends Topics with TableInfo<$TopicsTable, TopicRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TopicsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarRefMeta = const VerificationMeta(
    'avatarRef',
  );
  @override
  late final GeneratedColumn<String> avatarRef = GeneratedColumn<String>(
    'avatar_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _onlineMeta = const VerificationMeta('online');
  @override
  late final GeneratedColumn<bool> online = GeneratedColumn<bool>(
    'online',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("online" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isGroupMeta = const VerificationMeta(
    'isGroup',
  );
  @override
  late final GeneratedColumn<bool> isGroup = GeneratedColumn<bool>(
    'is_group',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_group" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _readSeqMeta = const VerificationMeta(
    'readSeq',
  );
  @override
  late final GeneratedColumn<int> readSeq = GeneratedColumn<int>(
    'read_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _recvSeqMeta = const VerificationMeta(
    'recvSeq',
  );
  @override
  late final GeneratedColumn<int> recvSeq = GeneratedColumn<int>(
    'recv_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _peerReadSeqMeta = const VerificationMeta(
    'peerReadSeq',
  );
  @override
  late final GeneratedColumn<int> peerReadSeq = GeneratedColumn<int>(
    'peer_read_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _peerRecvSeqMeta = const VerificationMeta(
    'peerRecvSeq',
  );
  @override
  late final GeneratedColumn<int> peerRecvSeq = GeneratedColumn<int>(
    'peer_recv_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastMessageSeqMeta = const VerificationMeta(
    'lastMessageSeq',
  );
  @override
  late final GeneratedColumn<int> lastMessageSeq = GeneratedColumn<int>(
    'last_message_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastMessageAtMeta = const VerificationMeta(
    'lastMessageAt',
  );
  @override
  late final GeneratedColumn<int> lastMessageAt = GeneratedColumn<int>(
    'last_message_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastPreviewMeta = const VerificationMeta(
    'lastPreview',
  );
  @override
  late final GeneratedColumn<String> lastPreview = GeneratedColumn<String>(
    'last_preview',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _draftMeta = const VerificationMeta('draft');
  @override
  late final GeneratedColumn<String> draft = GeneratedColumn<String>(
    'draft',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _deletionIdMeta = const VerificationMeta(
    'deletionId',
  );
  @override
  late final GeneratedColumn<int> deletionId = GeneratedColumn<int>(
    'deletion_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _coverageMeta = const VerificationMeta(
    'coverage',
  );
  @override
  late final GeneratedColumn<String> coverage = GeneratedColumn<String>(
    'coverage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _deletedRangesMeta = const VerificationMeta(
    'deletedRanges',
  );
  @override
  late final GeneratedColumn<String> deletedRanges = GeneratedColumn<String>(
    'deleted_ranges',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    scope,
    id,
    title,
    avatarRef,
    online,
    isGroup,
    serverSeq,
    readSeq,
    recvSeq,
    peerReadSeq,
    peerRecvSeq,
    lastMessageSeq,
    lastMessageAt,
    lastPreview,
    draft,
    deletionId,
    coverage,
    deletedRanges,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'topics';
  @override
  VerificationContext validateIntegrity(
    Insertable<TopicRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('avatar_ref')) {
      context.handle(
        _avatarRefMeta,
        avatarRef.isAcceptableOrUnknown(data['avatar_ref']!, _avatarRefMeta),
      );
    }
    if (data.containsKey('online')) {
      context.handle(
        _onlineMeta,
        online.isAcceptableOrUnknown(data['online']!, _onlineMeta),
      );
    }
    if (data.containsKey('is_group')) {
      context.handle(
        _isGroupMeta,
        isGroup.isAcceptableOrUnknown(data['is_group']!, _isGroupMeta),
      );
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('read_seq')) {
      context.handle(
        _readSeqMeta,
        readSeq.isAcceptableOrUnknown(data['read_seq']!, _readSeqMeta),
      );
    }
    if (data.containsKey('recv_seq')) {
      context.handle(
        _recvSeqMeta,
        recvSeq.isAcceptableOrUnknown(data['recv_seq']!, _recvSeqMeta),
      );
    }
    if (data.containsKey('peer_read_seq')) {
      context.handle(
        _peerReadSeqMeta,
        peerReadSeq.isAcceptableOrUnknown(
          data['peer_read_seq']!,
          _peerReadSeqMeta,
        ),
      );
    }
    if (data.containsKey('peer_recv_seq')) {
      context.handle(
        _peerRecvSeqMeta,
        peerRecvSeq.isAcceptableOrUnknown(
          data['peer_recv_seq']!,
          _peerRecvSeqMeta,
        ),
      );
    }
    if (data.containsKey('last_message_seq')) {
      context.handle(
        _lastMessageSeqMeta,
        lastMessageSeq.isAcceptableOrUnknown(
          data['last_message_seq']!,
          _lastMessageSeqMeta,
        ),
      );
    }
    if (data.containsKey('last_message_at')) {
      context.handle(
        _lastMessageAtMeta,
        lastMessageAt.isAcceptableOrUnknown(
          data['last_message_at']!,
          _lastMessageAtMeta,
        ),
      );
    }
    if (data.containsKey('last_preview')) {
      context.handle(
        _lastPreviewMeta,
        lastPreview.isAcceptableOrUnknown(
          data['last_preview']!,
          _lastPreviewMeta,
        ),
      );
    }
    if (data.containsKey('draft')) {
      context.handle(
        _draftMeta,
        draft.isAcceptableOrUnknown(data['draft']!, _draftMeta),
      );
    }
    if (data.containsKey('deletion_id')) {
      context.handle(
        _deletionIdMeta,
        deletionId.isAcceptableOrUnknown(data['deletion_id']!, _deletionIdMeta),
      );
    }
    if (data.containsKey('coverage')) {
      context.handle(
        _coverageMeta,
        coverage.isAcceptableOrUnknown(data['coverage']!, _coverageMeta),
      );
    }
    if (data.containsKey('deleted_ranges')) {
      context.handle(
        _deletedRangesMeta,
        deletedRanges.isAcceptableOrUnknown(
          data['deleted_ranges']!,
          _deletedRangesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope, id};
  @override
  TopicRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TopicRow(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      avatarRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_ref'],
      ),
      online: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}online'],
      )!,
      isGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_group'],
      )!,
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      )!,
      readSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}read_seq'],
      )!,
      recvSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recv_seq'],
      )!,
      peerReadSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}peer_read_seq'],
      )!,
      peerRecvSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}peer_recv_seq'],
      )!,
      lastMessageSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_message_seq'],
      )!,
      lastMessageAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_message_at'],
      ),
      lastPreview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_preview'],
      )!,
      draft: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft'],
      )!,
      deletionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deletion_id'],
      )!,
      coverage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}coverage'],
      )!,
      deletedRanges: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_ranges'],
      )!,
    );
  }

  @override
  $TopicsTable createAlias(String alias) {
    return $TopicsTable(attachedDatabase, alias);
  }
}

class TopicRow extends DataClass implements Insertable<TopicRow> {
  final String scope;
  final String id;
  final String title;
  final String? avatarRef;
  final bool online;
  final bool isGroup;
  final int serverSeq;
  final int readSeq;
  final int recvSeq;
  final int peerReadSeq;
  final int peerRecvSeq;
  final int lastMessageSeq;
  final int? lastMessageAt;
  final String lastPreview;
  final String draft;
  final int deletionId;
  final String coverage;
  final String deletedRanges;
  const TopicRow({
    required this.scope,
    required this.id,
    required this.title,
    this.avatarRef,
    required this.online,
    required this.isGroup,
    required this.serverSeq,
    required this.readSeq,
    required this.recvSeq,
    required this.peerReadSeq,
    required this.peerRecvSeq,
    required this.lastMessageSeq,
    this.lastMessageAt,
    required this.lastPreview,
    required this.draft,
    required this.deletionId,
    required this.coverage,
    required this.deletedRanges,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || avatarRef != null) {
      map['avatar_ref'] = Variable<String>(avatarRef);
    }
    map['online'] = Variable<bool>(online);
    map['is_group'] = Variable<bool>(isGroup);
    map['server_seq'] = Variable<int>(serverSeq);
    map['read_seq'] = Variable<int>(readSeq);
    map['recv_seq'] = Variable<int>(recvSeq);
    map['peer_read_seq'] = Variable<int>(peerReadSeq);
    map['peer_recv_seq'] = Variable<int>(peerRecvSeq);
    map['last_message_seq'] = Variable<int>(lastMessageSeq);
    if (!nullToAbsent || lastMessageAt != null) {
      map['last_message_at'] = Variable<int>(lastMessageAt);
    }
    map['last_preview'] = Variable<String>(lastPreview);
    map['draft'] = Variable<String>(draft);
    map['deletion_id'] = Variable<int>(deletionId);
    map['coverage'] = Variable<String>(coverage);
    map['deleted_ranges'] = Variable<String>(deletedRanges);
    return map;
  }

  TopicsCompanion toCompanion(bool nullToAbsent) {
    return TopicsCompanion(
      scope: Value(scope),
      id: Value(id),
      title: Value(title),
      avatarRef: avatarRef == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarRef),
      online: Value(online),
      isGroup: Value(isGroup),
      serverSeq: Value(serverSeq),
      readSeq: Value(readSeq),
      recvSeq: Value(recvSeq),
      peerReadSeq: Value(peerReadSeq),
      peerRecvSeq: Value(peerRecvSeq),
      lastMessageSeq: Value(lastMessageSeq),
      lastMessageAt: lastMessageAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageAt),
      lastPreview: Value(lastPreview),
      draft: Value(draft),
      deletionId: Value(deletionId),
      coverage: Value(coverage),
      deletedRanges: Value(deletedRanges),
    );
  }

  factory TopicRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TopicRow(
      scope: serializer.fromJson<String>(json['scope']),
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      avatarRef: serializer.fromJson<String?>(json['avatarRef']),
      online: serializer.fromJson<bool>(json['online']),
      isGroup: serializer.fromJson<bool>(json['isGroup']),
      serverSeq: serializer.fromJson<int>(json['serverSeq']),
      readSeq: serializer.fromJson<int>(json['readSeq']),
      recvSeq: serializer.fromJson<int>(json['recvSeq']),
      peerReadSeq: serializer.fromJson<int>(json['peerReadSeq']),
      peerRecvSeq: serializer.fromJson<int>(json['peerRecvSeq']),
      lastMessageSeq: serializer.fromJson<int>(json['lastMessageSeq']),
      lastMessageAt: serializer.fromJson<int?>(json['lastMessageAt']),
      lastPreview: serializer.fromJson<String>(json['lastPreview']),
      draft: serializer.fromJson<String>(json['draft']),
      deletionId: serializer.fromJson<int>(json['deletionId']),
      coverage: serializer.fromJson<String>(json['coverage']),
      deletedRanges: serializer.fromJson<String>(json['deletedRanges']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'avatarRef': serializer.toJson<String?>(avatarRef),
      'online': serializer.toJson<bool>(online),
      'isGroup': serializer.toJson<bool>(isGroup),
      'serverSeq': serializer.toJson<int>(serverSeq),
      'readSeq': serializer.toJson<int>(readSeq),
      'recvSeq': serializer.toJson<int>(recvSeq),
      'peerReadSeq': serializer.toJson<int>(peerReadSeq),
      'peerRecvSeq': serializer.toJson<int>(peerRecvSeq),
      'lastMessageSeq': serializer.toJson<int>(lastMessageSeq),
      'lastMessageAt': serializer.toJson<int?>(lastMessageAt),
      'lastPreview': serializer.toJson<String>(lastPreview),
      'draft': serializer.toJson<String>(draft),
      'deletionId': serializer.toJson<int>(deletionId),
      'coverage': serializer.toJson<String>(coverage),
      'deletedRanges': serializer.toJson<String>(deletedRanges),
    };
  }

  TopicRow copyWith({
    String? scope,
    String? id,
    String? title,
    Value<String?> avatarRef = const Value.absent(),
    bool? online,
    bool? isGroup,
    int? serverSeq,
    int? readSeq,
    int? recvSeq,
    int? peerReadSeq,
    int? peerRecvSeq,
    int? lastMessageSeq,
    Value<int?> lastMessageAt = const Value.absent(),
    String? lastPreview,
    String? draft,
    int? deletionId,
    String? coverage,
    String? deletedRanges,
  }) => TopicRow(
    scope: scope ?? this.scope,
    id: id ?? this.id,
    title: title ?? this.title,
    avatarRef: avatarRef.present ? avatarRef.value : this.avatarRef,
    online: online ?? this.online,
    isGroup: isGroup ?? this.isGroup,
    serverSeq: serverSeq ?? this.serverSeq,
    readSeq: readSeq ?? this.readSeq,
    recvSeq: recvSeq ?? this.recvSeq,
    peerReadSeq: peerReadSeq ?? this.peerReadSeq,
    peerRecvSeq: peerRecvSeq ?? this.peerRecvSeq,
    lastMessageSeq: lastMessageSeq ?? this.lastMessageSeq,
    lastMessageAt: lastMessageAt.present
        ? lastMessageAt.value
        : this.lastMessageAt,
    lastPreview: lastPreview ?? this.lastPreview,
    draft: draft ?? this.draft,
    deletionId: deletionId ?? this.deletionId,
    coverage: coverage ?? this.coverage,
    deletedRanges: deletedRanges ?? this.deletedRanges,
  );
  TopicRow copyWithCompanion(TopicsCompanion data) {
    return TopicRow(
      scope: data.scope.present ? data.scope.value : this.scope,
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      avatarRef: data.avatarRef.present ? data.avatarRef.value : this.avatarRef,
      online: data.online.present ? data.online.value : this.online,
      isGroup: data.isGroup.present ? data.isGroup.value : this.isGroup,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      readSeq: data.readSeq.present ? data.readSeq.value : this.readSeq,
      recvSeq: data.recvSeq.present ? data.recvSeq.value : this.recvSeq,
      peerReadSeq: data.peerReadSeq.present
          ? data.peerReadSeq.value
          : this.peerReadSeq,
      peerRecvSeq: data.peerRecvSeq.present
          ? data.peerRecvSeq.value
          : this.peerRecvSeq,
      lastMessageSeq: data.lastMessageSeq.present
          ? data.lastMessageSeq.value
          : this.lastMessageSeq,
      lastMessageAt: data.lastMessageAt.present
          ? data.lastMessageAt.value
          : this.lastMessageAt,
      lastPreview: data.lastPreview.present
          ? data.lastPreview.value
          : this.lastPreview,
      draft: data.draft.present ? data.draft.value : this.draft,
      deletionId: data.deletionId.present
          ? data.deletionId.value
          : this.deletionId,
      coverage: data.coverage.present ? data.coverage.value : this.coverage,
      deletedRanges: data.deletedRanges.present
          ? data.deletedRanges.value
          : this.deletedRanges,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TopicRow(')
          ..write('scope: $scope, ')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('avatarRef: $avatarRef, ')
          ..write('online: $online, ')
          ..write('isGroup: $isGroup, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('readSeq: $readSeq, ')
          ..write('recvSeq: $recvSeq, ')
          ..write('peerReadSeq: $peerReadSeq, ')
          ..write('peerRecvSeq: $peerRecvSeq, ')
          ..write('lastMessageSeq: $lastMessageSeq, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('lastPreview: $lastPreview, ')
          ..write('draft: $draft, ')
          ..write('deletionId: $deletionId, ')
          ..write('coverage: $coverage, ')
          ..write('deletedRanges: $deletedRanges')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scope,
    id,
    title,
    avatarRef,
    online,
    isGroup,
    serverSeq,
    readSeq,
    recvSeq,
    peerReadSeq,
    peerRecvSeq,
    lastMessageSeq,
    lastMessageAt,
    lastPreview,
    draft,
    deletionId,
    coverage,
    deletedRanges,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TopicRow &&
          other.scope == this.scope &&
          other.id == this.id &&
          other.title == this.title &&
          other.avatarRef == this.avatarRef &&
          other.online == this.online &&
          other.isGroup == this.isGroup &&
          other.serverSeq == this.serverSeq &&
          other.readSeq == this.readSeq &&
          other.recvSeq == this.recvSeq &&
          other.peerReadSeq == this.peerReadSeq &&
          other.peerRecvSeq == this.peerRecvSeq &&
          other.lastMessageSeq == this.lastMessageSeq &&
          other.lastMessageAt == this.lastMessageAt &&
          other.lastPreview == this.lastPreview &&
          other.draft == this.draft &&
          other.deletionId == this.deletionId &&
          other.coverage == this.coverage &&
          other.deletedRanges == this.deletedRanges);
}

class TopicsCompanion extends UpdateCompanion<TopicRow> {
  final Value<String> scope;
  final Value<String> id;
  final Value<String> title;
  final Value<String?> avatarRef;
  final Value<bool> online;
  final Value<bool> isGroup;
  final Value<int> serverSeq;
  final Value<int> readSeq;
  final Value<int> recvSeq;
  final Value<int> peerReadSeq;
  final Value<int> peerRecvSeq;
  final Value<int> lastMessageSeq;
  final Value<int?> lastMessageAt;
  final Value<String> lastPreview;
  final Value<String> draft;
  final Value<int> deletionId;
  final Value<String> coverage;
  final Value<String> deletedRanges;
  final Value<int> rowid;
  const TopicsCompanion({
    this.scope = const Value.absent(),
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.avatarRef = const Value.absent(),
    this.online = const Value.absent(),
    this.isGroup = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.readSeq = const Value.absent(),
    this.recvSeq = const Value.absent(),
    this.peerReadSeq = const Value.absent(),
    this.peerRecvSeq = const Value.absent(),
    this.lastMessageSeq = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.lastPreview = const Value.absent(),
    this.draft = const Value.absent(),
    this.deletionId = const Value.absent(),
    this.coverage = const Value.absent(),
    this.deletedRanges = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TopicsCompanion.insert({
    required String scope,
    required String id,
    required String title,
    this.avatarRef = const Value.absent(),
    this.online = const Value.absent(),
    this.isGroup = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.readSeq = const Value.absent(),
    this.recvSeq = const Value.absent(),
    this.peerReadSeq = const Value.absent(),
    this.peerRecvSeq = const Value.absent(),
    this.lastMessageSeq = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.lastPreview = const Value.absent(),
    this.draft = const Value.absent(),
    this.deletionId = const Value.absent(),
    this.coverage = const Value.absent(),
    this.deletedRanges = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scope = Value(scope),
       id = Value(id),
       title = Value(title);
  static Insertable<TopicRow> custom({
    Expression<String>? scope,
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? avatarRef,
    Expression<bool>? online,
    Expression<bool>? isGroup,
    Expression<int>? serverSeq,
    Expression<int>? readSeq,
    Expression<int>? recvSeq,
    Expression<int>? peerReadSeq,
    Expression<int>? peerRecvSeq,
    Expression<int>? lastMessageSeq,
    Expression<int>? lastMessageAt,
    Expression<String>? lastPreview,
    Expression<String>? draft,
    Expression<int>? deletionId,
    Expression<String>? coverage,
    Expression<String>? deletedRanges,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (avatarRef != null) 'avatar_ref': avatarRef,
      if (online != null) 'online': online,
      if (isGroup != null) 'is_group': isGroup,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (readSeq != null) 'read_seq': readSeq,
      if (recvSeq != null) 'recv_seq': recvSeq,
      if (peerReadSeq != null) 'peer_read_seq': peerReadSeq,
      if (peerRecvSeq != null) 'peer_recv_seq': peerRecvSeq,
      if (lastMessageSeq != null) 'last_message_seq': lastMessageSeq,
      if (lastMessageAt != null) 'last_message_at': lastMessageAt,
      if (lastPreview != null) 'last_preview': lastPreview,
      if (draft != null) 'draft': draft,
      if (deletionId != null) 'deletion_id': deletionId,
      if (coverage != null) 'coverage': coverage,
      if (deletedRanges != null) 'deleted_ranges': deletedRanges,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TopicsCompanion copyWith({
    Value<String>? scope,
    Value<String>? id,
    Value<String>? title,
    Value<String?>? avatarRef,
    Value<bool>? online,
    Value<bool>? isGroup,
    Value<int>? serverSeq,
    Value<int>? readSeq,
    Value<int>? recvSeq,
    Value<int>? peerReadSeq,
    Value<int>? peerRecvSeq,
    Value<int>? lastMessageSeq,
    Value<int?>? lastMessageAt,
    Value<String>? lastPreview,
    Value<String>? draft,
    Value<int>? deletionId,
    Value<String>? coverage,
    Value<String>? deletedRanges,
    Value<int>? rowid,
  }) {
    return TopicsCompanion(
      scope: scope ?? this.scope,
      id: id ?? this.id,
      title: title ?? this.title,
      avatarRef: avatarRef ?? this.avatarRef,
      online: online ?? this.online,
      isGroup: isGroup ?? this.isGroup,
      serverSeq: serverSeq ?? this.serverSeq,
      readSeq: readSeq ?? this.readSeq,
      recvSeq: recvSeq ?? this.recvSeq,
      peerReadSeq: peerReadSeq ?? this.peerReadSeq,
      peerRecvSeq: peerRecvSeq ?? this.peerRecvSeq,
      lastMessageSeq: lastMessageSeq ?? this.lastMessageSeq,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastPreview: lastPreview ?? this.lastPreview,
      draft: draft ?? this.draft,
      deletionId: deletionId ?? this.deletionId,
      coverage: coverage ?? this.coverage,
      deletedRanges: deletedRanges ?? this.deletedRanges,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (avatarRef.present) {
      map['avatar_ref'] = Variable<String>(avatarRef.value);
    }
    if (online.present) {
      map['online'] = Variable<bool>(online.value);
    }
    if (isGroup.present) {
      map['is_group'] = Variable<bool>(isGroup.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (readSeq.present) {
      map['read_seq'] = Variable<int>(readSeq.value);
    }
    if (recvSeq.present) {
      map['recv_seq'] = Variable<int>(recvSeq.value);
    }
    if (peerReadSeq.present) {
      map['peer_read_seq'] = Variable<int>(peerReadSeq.value);
    }
    if (peerRecvSeq.present) {
      map['peer_recv_seq'] = Variable<int>(peerRecvSeq.value);
    }
    if (lastMessageSeq.present) {
      map['last_message_seq'] = Variable<int>(lastMessageSeq.value);
    }
    if (lastMessageAt.present) {
      map['last_message_at'] = Variable<int>(lastMessageAt.value);
    }
    if (lastPreview.present) {
      map['last_preview'] = Variable<String>(lastPreview.value);
    }
    if (draft.present) {
      map['draft'] = Variable<String>(draft.value);
    }
    if (deletionId.present) {
      map['deletion_id'] = Variable<int>(deletionId.value);
    }
    if (coverage.present) {
      map['coverage'] = Variable<String>(coverage.value);
    }
    if (deletedRanges.present) {
      map['deleted_ranges'] = Variable<String>(deletedRanges.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TopicsCompanion(')
          ..write('scope: $scope, ')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('avatarRef: $avatarRef, ')
          ..write('online: $online, ')
          ..write('isGroup: $isGroup, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('readSeq: $readSeq, ')
          ..write('recvSeq: $recvSeq, ')
          ..write('peerReadSeq: $peerReadSeq, ')
          ..write('peerRecvSeq: $peerRecvSeq, ')
          ..write('lastMessageSeq: $lastMessageSeq, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('lastPreview: $lastPreview, ')
          ..write('draft: $draft, ')
          ..write('deletionId: $deletionId, ')
          ..write('coverage: $coverage, ')
          ..write('deletedRanges: $deletedRanges, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages
    with TableInfo<$MessagesTable, MessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topicIdMeta = const VerificationMeta(
    'topicId',
  );
  @override
  late final GeneratedColumn<String> topicId = GeneratedColumn<String>(
    'topic_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localSeqMeta = const VerificationMeta(
    'localSeq',
  );
  @override
  late final GeneratedColumn<int> localSeq = GeneratedColumn<int>(
    'local_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
    'sender_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _headMeta = const VerificationMeta('head');
  @override
  late final GeneratedColumn<String> head = GeneratedColumn<String>(
    'head',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _deliveryMeta = const VerificationMeta(
    'delivery',
  );
  @override
  late final GeneratedColumn<int> delivery = GeneratedColumn<int>(
    'delivery',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    scope,
    topicId,
    seq,
    clientId,
    localSeq,
    senderId,
    createdAtMs,
    content,
    head,
    delivery,
    hidden,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('topic_id')) {
      context.handle(
        _topicIdMeta,
        topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_topicIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('local_seq')) {
      context.handle(
        _localSeqMeta,
        localSeq.isAcceptableOrUnknown(data['local_seq']!, _localSeqMeta),
      );
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('head')) {
      context.handle(
        _headMeta,
        head.isAcceptableOrUnknown(data['head']!, _headMeta),
      );
    }
    if (data.containsKey('delivery')) {
      context.handle(
        _deliveryMeta,
        delivery.isAcceptableOrUnknown(data['delivery']!, _deliveryMeta),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope, topicId, seq};
  @override
  MessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageRow(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      topicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      localSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_seq'],
      )!,
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_id'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      head: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}head'],
      )!,
      delivery: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}delivery'],
      )!,
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class MessageRow extends DataClass implements Insertable<MessageRow> {
  final String scope;
  final String topicId;
  final int seq;
  final String clientId;
  final int localSeq;
  final String senderId;
  final int createdAtMs;
  final String content;
  final String head;
  final int delivery;
  final bool hidden;
  final bool deleted;
  const MessageRow({
    required this.scope,
    required this.topicId,
    required this.seq,
    required this.clientId,
    required this.localSeq,
    required this.senderId,
    required this.createdAtMs,
    required this.content,
    required this.head,
    required this.delivery,
    required this.hidden,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['topic_id'] = Variable<String>(topicId);
    map['seq'] = Variable<int>(seq);
    map['client_id'] = Variable<String>(clientId);
    map['local_seq'] = Variable<int>(localSeq);
    map['sender_id'] = Variable<String>(senderId);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['content'] = Variable<String>(content);
    map['head'] = Variable<String>(head);
    map['delivery'] = Variable<int>(delivery);
    map['hidden'] = Variable<bool>(hidden);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      scope: Value(scope),
      topicId: Value(topicId),
      seq: Value(seq),
      clientId: Value(clientId),
      localSeq: Value(localSeq),
      senderId: Value(senderId),
      createdAtMs: Value(createdAtMs),
      content: Value(content),
      head: Value(head),
      delivery: Value(delivery),
      hidden: Value(hidden),
      deleted: Value(deleted),
    );
  }

  factory MessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageRow(
      scope: serializer.fromJson<String>(json['scope']),
      topicId: serializer.fromJson<String>(json['topicId']),
      seq: serializer.fromJson<int>(json['seq']),
      clientId: serializer.fromJson<String>(json['clientId']),
      localSeq: serializer.fromJson<int>(json['localSeq']),
      senderId: serializer.fromJson<String>(json['senderId']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      content: serializer.fromJson<String>(json['content']),
      head: serializer.fromJson<String>(json['head']),
      delivery: serializer.fromJson<int>(json['delivery']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'topicId': serializer.toJson<String>(topicId),
      'seq': serializer.toJson<int>(seq),
      'clientId': serializer.toJson<String>(clientId),
      'localSeq': serializer.toJson<int>(localSeq),
      'senderId': serializer.toJson<String>(senderId),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'content': serializer.toJson<String>(content),
      'head': serializer.toJson<String>(head),
      'delivery': serializer.toJson<int>(delivery),
      'hidden': serializer.toJson<bool>(hidden),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  MessageRow copyWith({
    String? scope,
    String? topicId,
    int? seq,
    String? clientId,
    int? localSeq,
    String? senderId,
    int? createdAtMs,
    String? content,
    String? head,
    int? delivery,
    bool? hidden,
    bool? deleted,
  }) => MessageRow(
    scope: scope ?? this.scope,
    topicId: topicId ?? this.topicId,
    seq: seq ?? this.seq,
    clientId: clientId ?? this.clientId,
    localSeq: localSeq ?? this.localSeq,
    senderId: senderId ?? this.senderId,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    content: content ?? this.content,
    head: head ?? this.head,
    delivery: delivery ?? this.delivery,
    hidden: hidden ?? this.hidden,
    deleted: deleted ?? this.deleted,
  );
  MessageRow copyWithCompanion(MessagesCompanion data) {
    return MessageRow(
      scope: data.scope.present ? data.scope.value : this.scope,
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
      seq: data.seq.present ? data.seq.value : this.seq,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      localSeq: data.localSeq.present ? data.localSeq.value : this.localSeq,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      content: data.content.present ? data.content.value : this.content,
      head: data.head.present ? data.head.value : this.head,
      delivery: data.delivery.present ? data.delivery.value : this.delivery,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageRow(')
          ..write('scope: $scope, ')
          ..write('topicId: $topicId, ')
          ..write('seq: $seq, ')
          ..write('clientId: $clientId, ')
          ..write('localSeq: $localSeq, ')
          ..write('senderId: $senderId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('content: $content, ')
          ..write('head: $head, ')
          ..write('delivery: $delivery, ')
          ..write('hidden: $hidden, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scope,
    topicId,
    seq,
    clientId,
    localSeq,
    senderId,
    createdAtMs,
    content,
    head,
    delivery,
    hidden,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageRow &&
          other.scope == this.scope &&
          other.topicId == this.topicId &&
          other.seq == this.seq &&
          other.clientId == this.clientId &&
          other.localSeq == this.localSeq &&
          other.senderId == this.senderId &&
          other.createdAtMs == this.createdAtMs &&
          other.content == this.content &&
          other.head == this.head &&
          other.delivery == this.delivery &&
          other.hidden == this.hidden &&
          other.deleted == this.deleted);
}

class MessagesCompanion extends UpdateCompanion<MessageRow> {
  final Value<String> scope;
  final Value<String> topicId;
  final Value<int> seq;
  final Value<String> clientId;
  final Value<int> localSeq;
  final Value<String> senderId;
  final Value<int> createdAtMs;
  final Value<String> content;
  final Value<String> head;
  final Value<int> delivery;
  final Value<bool> hidden;
  final Value<bool> deleted;
  final Value<int> rowid;
  const MessagesCompanion({
    this.scope = const Value.absent(),
    this.topicId = const Value.absent(),
    this.seq = const Value.absent(),
    this.clientId = const Value.absent(),
    this.localSeq = const Value.absent(),
    this.senderId = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.content = const Value.absent(),
    this.head = const Value.absent(),
    this.delivery = const Value.absent(),
    this.hidden = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String scope,
    required String topicId,
    required int seq,
    required String clientId,
    this.localSeq = const Value.absent(),
    required String senderId,
    required int createdAtMs,
    required String content,
    this.head = const Value.absent(),
    this.delivery = const Value.absent(),
    this.hidden = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scope = Value(scope),
       topicId = Value(topicId),
       seq = Value(seq),
       clientId = Value(clientId),
       senderId = Value(senderId),
       createdAtMs = Value(createdAtMs),
       content = Value(content);
  static Insertable<MessageRow> custom({
    Expression<String>? scope,
    Expression<String>? topicId,
    Expression<int>? seq,
    Expression<String>? clientId,
    Expression<int>? localSeq,
    Expression<String>? senderId,
    Expression<int>? createdAtMs,
    Expression<String>? content,
    Expression<String>? head,
    Expression<int>? delivery,
    Expression<bool>? hidden,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (topicId != null) 'topic_id': topicId,
      if (seq != null) 'seq': seq,
      if (clientId != null) 'client_id': clientId,
      if (localSeq != null) 'local_seq': localSeq,
      if (senderId != null) 'sender_id': senderId,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (content != null) 'content': content,
      if (head != null) 'head': head,
      if (delivery != null) 'delivery': delivery,
      if (hidden != null) 'hidden': hidden,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? scope,
    Value<String>? topicId,
    Value<int>? seq,
    Value<String>? clientId,
    Value<int>? localSeq,
    Value<String>? senderId,
    Value<int>? createdAtMs,
    Value<String>? content,
    Value<String>? head,
    Value<int>? delivery,
    Value<bool>? hidden,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      scope: scope ?? this.scope,
      topicId: topicId ?? this.topicId,
      seq: seq ?? this.seq,
      clientId: clientId ?? this.clientId,
      localSeq: localSeq ?? this.localSeq,
      senderId: senderId ?? this.senderId,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      content: content ?? this.content,
      head: head ?? this.head,
      delivery: delivery ?? this.delivery,
      hidden: hidden ?? this.hidden,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (topicId.present) {
      map['topic_id'] = Variable<String>(topicId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (localSeq.present) {
      map['local_seq'] = Variable<int>(localSeq.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (head.present) {
      map['head'] = Variable<String>(head.value);
    }
    if (delivery.present) {
      map['delivery'] = Variable<int>(delivery.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('scope: $scope, ')
          ..write('topicId: $topicId, ')
          ..write('seq: $seq, ')
          ..write('clientId: $clientId, ')
          ..write('localSeq: $localSeq, ')
          ..write('senderId: $senderId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('content: $content, ')
          ..write('head: $head, ')
          ..write('delivery: $delivery, ')
          ..write('hidden: $hidden, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topicIdMeta = const VerificationMeta(
    'topicId',
  );
  @override
  late final GeneratedColumn<String> topicId = GeneratedColumn<String>(
    'topic_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localSeqMeta = const VerificationMeta(
    'localSeq',
  );
  @override
  late final GeneratedColumn<int> localSeq = GeneratedColumn<int>(
    'local_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _afterSeqMeta = const VerificationMeta(
    'afterSeq',
  );
  @override
  late final GeneratedColumn<int> afterSeq = GeneratedColumn<int>(
    'after_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<int> nextRetryAt = GeneratedColumn<int>(
    'next_retry_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ambiguousMeta = const VerificationMeta(
    'ambiguous',
  );
  @override
  late final GeneratedColumn<bool> ambiguous = GeneratedColumn<bool>(
    'ambiguous',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("ambiguous" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scope,
    clientId,
    topicId,
    localSeq,
    afterSeq,
    attempts,
    nextRetryAt,
    ambiguous,
    error,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('topic_id')) {
      context.handle(
        _topicIdMeta,
        topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_topicIdMeta);
    }
    if (data.containsKey('local_seq')) {
      context.handle(
        _localSeqMeta,
        localSeq.isAcceptableOrUnknown(data['local_seq']!, _localSeqMeta),
      );
    } else if (isInserting) {
      context.missing(_localSeqMeta);
    }
    if (data.containsKey('after_seq')) {
      context.handle(
        _afterSeqMeta,
        afterSeq.isAcceptableOrUnknown(data['after_seq']!, _afterSeqMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    }
    if (data.containsKey('ambiguous')) {
      context.handle(
        _ambiguousMeta,
        ambiguous.isAcceptableOrUnknown(data['ambiguous']!, _ambiguousMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope, clientId};
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      topicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic_id'],
      )!,
      localSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_seq'],
      )!,
      afterSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}after_seq'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_retry_at'],
      )!,
      ambiguous: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ambiguous'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final String scope;
  final String clientId;
  final String topicId;
  final int localSeq;
  final int afterSeq;
  final int attempts;
  final int nextRetryAt;
  final bool ambiguous;
  final String? error;
  const OutboxRow({
    required this.scope,
    required this.clientId,
    required this.topicId,
    required this.localSeq,
    required this.afterSeq,
    required this.attempts,
    required this.nextRetryAt,
    required this.ambiguous,
    this.error,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['client_id'] = Variable<String>(clientId);
    map['topic_id'] = Variable<String>(topicId);
    map['local_seq'] = Variable<int>(localSeq);
    map['after_seq'] = Variable<int>(afterSeq);
    map['attempts'] = Variable<int>(attempts);
    map['next_retry_at'] = Variable<int>(nextRetryAt);
    map['ambiguous'] = Variable<bool>(ambiguous);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      scope: Value(scope),
      clientId: Value(clientId),
      topicId: Value(topicId),
      localSeq: Value(localSeq),
      afterSeq: Value(afterSeq),
      attempts: Value(attempts),
      nextRetryAt: Value(nextRetryAt),
      ambiguous: Value(ambiguous),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      scope: serializer.fromJson<String>(json['scope']),
      clientId: serializer.fromJson<String>(json['clientId']),
      topicId: serializer.fromJson<String>(json['topicId']),
      localSeq: serializer.fromJson<int>(json['localSeq']),
      afterSeq: serializer.fromJson<int>(json['afterSeq']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextRetryAt: serializer.fromJson<int>(json['nextRetryAt']),
      ambiguous: serializer.fromJson<bool>(json['ambiguous']),
      error: serializer.fromJson<String?>(json['error']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'clientId': serializer.toJson<String>(clientId),
      'topicId': serializer.toJson<String>(topicId),
      'localSeq': serializer.toJson<int>(localSeq),
      'afterSeq': serializer.toJson<int>(afterSeq),
      'attempts': serializer.toJson<int>(attempts),
      'nextRetryAt': serializer.toJson<int>(nextRetryAt),
      'ambiguous': serializer.toJson<bool>(ambiguous),
      'error': serializer.toJson<String?>(error),
    };
  }

  OutboxRow copyWith({
    String? scope,
    String? clientId,
    String? topicId,
    int? localSeq,
    int? afterSeq,
    int? attempts,
    int? nextRetryAt,
    bool? ambiguous,
    Value<String?> error = const Value.absent(),
  }) => OutboxRow(
    scope: scope ?? this.scope,
    clientId: clientId ?? this.clientId,
    topicId: topicId ?? this.topicId,
    localSeq: localSeq ?? this.localSeq,
    afterSeq: afterSeq ?? this.afterSeq,
    attempts: attempts ?? this.attempts,
    nextRetryAt: nextRetryAt ?? this.nextRetryAt,
    ambiguous: ambiguous ?? this.ambiguous,
    error: error.present ? error.value : this.error,
  );
  OutboxRow copyWithCompanion(OutboxCompanion data) {
    return OutboxRow(
      scope: data.scope.present ? data.scope.value : this.scope,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
      localSeq: data.localSeq.present ? data.localSeq.value : this.localSeq,
      afterSeq: data.afterSeq.present ? data.afterSeq.value : this.afterSeq,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      ambiguous: data.ambiguous.present ? data.ambiguous.value : this.ambiguous,
      error: data.error.present ? data.error.value : this.error,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('scope: $scope, ')
          ..write('clientId: $clientId, ')
          ..write('topicId: $topicId, ')
          ..write('localSeq: $localSeq, ')
          ..write('afterSeq: $afterSeq, ')
          ..write('attempts: $attempts, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('ambiguous: $ambiguous, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scope,
    clientId,
    topicId,
    localSeq,
    afterSeq,
    attempts,
    nextRetryAt,
    ambiguous,
    error,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.scope == this.scope &&
          other.clientId == this.clientId &&
          other.topicId == this.topicId &&
          other.localSeq == this.localSeq &&
          other.afterSeq == this.afterSeq &&
          other.attempts == this.attempts &&
          other.nextRetryAt == this.nextRetryAt &&
          other.ambiguous == this.ambiguous &&
          other.error == this.error);
}

class OutboxCompanion extends UpdateCompanion<OutboxRow> {
  final Value<String> scope;
  final Value<String> clientId;
  final Value<String> topicId;
  final Value<int> localSeq;
  final Value<int> afterSeq;
  final Value<int> attempts;
  final Value<int> nextRetryAt;
  final Value<bool> ambiguous;
  final Value<String?> error;
  final Value<int> rowid;
  const OutboxCompanion({
    this.scope = const Value.absent(),
    this.clientId = const Value.absent(),
    this.topicId = const Value.absent(),
    this.localSeq = const Value.absent(),
    this.afterSeq = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.ambiguous = const Value.absent(),
    this.error = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String scope,
    required String clientId,
    required String topicId,
    required int localSeq,
    this.afterSeq = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.ambiguous = const Value.absent(),
    this.error = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scope = Value(scope),
       clientId = Value(clientId),
       topicId = Value(topicId),
       localSeq = Value(localSeq);
  static Insertable<OutboxRow> custom({
    Expression<String>? scope,
    Expression<String>? clientId,
    Expression<String>? topicId,
    Expression<int>? localSeq,
    Expression<int>? afterSeq,
    Expression<int>? attempts,
    Expression<int>? nextRetryAt,
    Expression<bool>? ambiguous,
    Expression<String>? error,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (clientId != null) 'client_id': clientId,
      if (topicId != null) 'topic_id': topicId,
      if (localSeq != null) 'local_seq': localSeq,
      if (afterSeq != null) 'after_seq': afterSeq,
      if (attempts != null) 'attempts': attempts,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (ambiguous != null) 'ambiguous': ambiguous,
      if (error != null) 'error': error,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? scope,
    Value<String>? clientId,
    Value<String>? topicId,
    Value<int>? localSeq,
    Value<int>? afterSeq,
    Value<int>? attempts,
    Value<int>? nextRetryAt,
    Value<bool>? ambiguous,
    Value<String?>? error,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      scope: scope ?? this.scope,
      clientId: clientId ?? this.clientId,
      topicId: topicId ?? this.topicId,
      localSeq: localSeq ?? this.localSeq,
      afterSeq: afterSeq ?? this.afterSeq,
      attempts: attempts ?? this.attempts,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      ambiguous: ambiguous ?? this.ambiguous,
      error: error ?? this.error,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (topicId.present) {
      map['topic_id'] = Variable<String>(topicId.value);
    }
    if (localSeq.present) {
      map['local_seq'] = Variable<int>(localSeq.value);
    }
    if (afterSeq.present) {
      map['after_seq'] = Variable<int>(afterSeq.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<int>(nextRetryAt.value);
    }
    if (ambiguous.present) {
      map['ambiguous'] = Variable<bool>(ambiguous.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('scope: $scope, ')
          ..write('clientId: $clientId, ')
          ..write('topicId: $topicId, ')
          ..write('localSeq: $localSeq, ')
          ..write('afterSeq: $afterSeq, ')
          ..write('attempts: $attempts, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('ambiguous: $ambiguous, ')
          ..write('error: $error, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxAttachmentsTable extends OutboxAttachments
    with TableInfo<$OutboxAttachmentsTable, OutboxAttachmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxAttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIndexMeta = const VerificationMeta(
    'entityIndex',
  );
  @override
  late final GeneratedColumn<int> entityIndex = GeneratedColumn<int>(
    'entity_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteRefMeta = const VerificationMeta(
    'remoteRef',
  );
  @override
  late final GeneratedColumn<String> remoteRef = GeneratedColumn<String>(
    'remote_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scope,
    clientId,
    entityIndex,
    bytes,
    name,
    mime,
    remoteRef,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxAttachmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('entity_index')) {
      context.handle(
        _entityIndexMeta,
        entityIndex.isAcceptableOrUnknown(
          data['entity_index']!,
          _entityIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_entityIndexMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeMeta);
    }
    if (data.containsKey('remote_ref')) {
      context.handle(
        _remoteRefMeta,
        remoteRef.isAcceptableOrUnknown(data['remote_ref']!, _remoteRefMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope, clientId, entityIndex};
  @override
  OutboxAttachmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxAttachmentRow(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      entityIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entity_index'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}bytes'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      )!,
      remoteRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_ref'],
      ),
    );
  }

  @override
  $OutboxAttachmentsTable createAlias(String alias) {
    return $OutboxAttachmentsTable(attachedDatabase, alias);
  }
}

class OutboxAttachmentRow extends DataClass
    implements Insertable<OutboxAttachmentRow> {
  final String scope;
  final String clientId;
  final int entityIndex;
  final Uint8List bytes;
  final String name;
  final String mime;
  final String? remoteRef;
  const OutboxAttachmentRow({
    required this.scope,
    required this.clientId,
    required this.entityIndex,
    required this.bytes,
    required this.name,
    required this.mime,
    this.remoteRef,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['client_id'] = Variable<String>(clientId);
    map['entity_index'] = Variable<int>(entityIndex);
    map['bytes'] = Variable<Uint8List>(bytes);
    map['name'] = Variable<String>(name);
    map['mime'] = Variable<String>(mime);
    if (!nullToAbsent || remoteRef != null) {
      map['remote_ref'] = Variable<String>(remoteRef);
    }
    return map;
  }

  OutboxAttachmentsCompanion toCompanion(bool nullToAbsent) {
    return OutboxAttachmentsCompanion(
      scope: Value(scope),
      clientId: Value(clientId),
      entityIndex: Value(entityIndex),
      bytes: Value(bytes),
      name: Value(name),
      mime: Value(mime),
      remoteRef: remoteRef == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteRef),
    );
  }

  factory OutboxAttachmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxAttachmentRow(
      scope: serializer.fromJson<String>(json['scope']),
      clientId: serializer.fromJson<String>(json['clientId']),
      entityIndex: serializer.fromJson<int>(json['entityIndex']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
      name: serializer.fromJson<String>(json['name']),
      mime: serializer.fromJson<String>(json['mime']),
      remoteRef: serializer.fromJson<String?>(json['remoteRef']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'clientId': serializer.toJson<String>(clientId),
      'entityIndex': serializer.toJson<int>(entityIndex),
      'bytes': serializer.toJson<Uint8List>(bytes),
      'name': serializer.toJson<String>(name),
      'mime': serializer.toJson<String>(mime),
      'remoteRef': serializer.toJson<String?>(remoteRef),
    };
  }

  OutboxAttachmentRow copyWith({
    String? scope,
    String? clientId,
    int? entityIndex,
    Uint8List? bytes,
    String? name,
    String? mime,
    Value<String?> remoteRef = const Value.absent(),
  }) => OutboxAttachmentRow(
    scope: scope ?? this.scope,
    clientId: clientId ?? this.clientId,
    entityIndex: entityIndex ?? this.entityIndex,
    bytes: bytes ?? this.bytes,
    name: name ?? this.name,
    mime: mime ?? this.mime,
    remoteRef: remoteRef.present ? remoteRef.value : this.remoteRef,
  );
  OutboxAttachmentRow copyWithCompanion(OutboxAttachmentsCompanion data) {
    return OutboxAttachmentRow(
      scope: data.scope.present ? data.scope.value : this.scope,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      entityIndex: data.entityIndex.present
          ? data.entityIndex.value
          : this.entityIndex,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      name: data.name.present ? data.name.value : this.name,
      mime: data.mime.present ? data.mime.value : this.mime,
      remoteRef: data.remoteRef.present ? data.remoteRef.value : this.remoteRef,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxAttachmentRow(')
          ..write('scope: $scope, ')
          ..write('clientId: $clientId, ')
          ..write('entityIndex: $entityIndex, ')
          ..write('bytes: $bytes, ')
          ..write('name: $name, ')
          ..write('mime: $mime, ')
          ..write('remoteRef: $remoteRef')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scope,
    clientId,
    entityIndex,
    $driftBlobEquality.hash(bytes),
    name,
    mime,
    remoteRef,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxAttachmentRow &&
          other.scope == this.scope &&
          other.clientId == this.clientId &&
          other.entityIndex == this.entityIndex &&
          $driftBlobEquality.equals(other.bytes, this.bytes) &&
          other.name == this.name &&
          other.mime == this.mime &&
          other.remoteRef == this.remoteRef);
}

class OutboxAttachmentsCompanion extends UpdateCompanion<OutboxAttachmentRow> {
  final Value<String> scope;
  final Value<String> clientId;
  final Value<int> entityIndex;
  final Value<Uint8List> bytes;
  final Value<String> name;
  final Value<String> mime;
  final Value<String?> remoteRef;
  final Value<int> rowid;
  const OutboxAttachmentsCompanion({
    this.scope = const Value.absent(),
    this.clientId = const Value.absent(),
    this.entityIndex = const Value.absent(),
    this.bytes = const Value.absent(),
    this.name = const Value.absent(),
    this.mime = const Value.absent(),
    this.remoteRef = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxAttachmentsCompanion.insert({
    required String scope,
    required String clientId,
    required int entityIndex,
    required Uint8List bytes,
    required String name,
    required String mime,
    this.remoteRef = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scope = Value(scope),
       clientId = Value(clientId),
       entityIndex = Value(entityIndex),
       bytes = Value(bytes),
       name = Value(name),
       mime = Value(mime);
  static Insertable<OutboxAttachmentRow> custom({
    Expression<String>? scope,
    Expression<String>? clientId,
    Expression<int>? entityIndex,
    Expression<Uint8List>? bytes,
    Expression<String>? name,
    Expression<String>? mime,
    Expression<String>? remoteRef,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (clientId != null) 'client_id': clientId,
      if (entityIndex != null) 'entity_index': entityIndex,
      if (bytes != null) 'bytes': bytes,
      if (name != null) 'name': name,
      if (mime != null) 'mime': mime,
      if (remoteRef != null) 'remote_ref': remoteRef,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxAttachmentsCompanion copyWith({
    Value<String>? scope,
    Value<String>? clientId,
    Value<int>? entityIndex,
    Value<Uint8List>? bytes,
    Value<String>? name,
    Value<String>? mime,
    Value<String?>? remoteRef,
    Value<int>? rowid,
  }) {
    return OutboxAttachmentsCompanion(
      scope: scope ?? this.scope,
      clientId: clientId ?? this.clientId,
      entityIndex: entityIndex ?? this.entityIndex,
      bytes: bytes ?? this.bytes,
      name: name ?? this.name,
      mime: mime ?? this.mime,
      remoteRef: remoteRef ?? this.remoteRef,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (entityIndex.present) {
      map['entity_index'] = Variable<int>(entityIndex.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (remoteRef.present) {
      map['remote_ref'] = Variable<String>(remoteRef.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxAttachmentsCompanion(')
          ..write('scope: $scope, ')
          ..write('clientId: $clientId, ')
          ..write('entityIndex: $entityIndex, ')
          ..write('bytes: $bytes, ')
          ..write('name: $name, ')
          ..write('mime: $mime, ')
          ..write('remoteRef: $remoteRef, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageSearchTable extends MessageSearch
    with TableInfo<$MessageSearchTable, MessageSearchRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageSearchTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topicIdMeta = const VerificationMeta(
    'topicId',
  );
  @override
  late final GeneratedColumn<String> topicId = GeneratedColumn<String>(
    'topic_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, scope, topicId, seq, body];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_search';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageSearchRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('topic_id')) {
      context.handle(
        _topicIdMeta,
        topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_topicIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {scope, topicId, seq},
  ];
  @override
  MessageSearchRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageSearchRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      topicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
    );
  }

  @override
  $MessageSearchTable createAlias(String alias) {
    return $MessageSearchTable(attachedDatabase, alias);
  }
}

class MessageSearchRow extends DataClass
    implements Insertable<MessageSearchRow> {
  final int id;
  final String scope;
  final String topicId;
  final int seq;
  final String body;
  const MessageSearchRow({
    required this.id,
    required this.scope,
    required this.topicId,
    required this.seq,
    required this.body,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['scope'] = Variable<String>(scope);
    map['topic_id'] = Variable<String>(topicId);
    map['seq'] = Variable<int>(seq);
    map['body'] = Variable<String>(body);
    return map;
  }

  MessageSearchCompanion toCompanion(bool nullToAbsent) {
    return MessageSearchCompanion(
      id: Value(id),
      scope: Value(scope),
      topicId: Value(topicId),
      seq: Value(seq),
      body: Value(body),
    );
  }

  factory MessageSearchRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageSearchRow(
      id: serializer.fromJson<int>(json['id']),
      scope: serializer.fromJson<String>(json['scope']),
      topicId: serializer.fromJson<String>(json['topicId']),
      seq: serializer.fromJson<int>(json['seq']),
      body: serializer.fromJson<String>(json['body']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'scope': serializer.toJson<String>(scope),
      'topicId': serializer.toJson<String>(topicId),
      'seq': serializer.toJson<int>(seq),
      'body': serializer.toJson<String>(body),
    };
  }

  MessageSearchRow copyWith({
    int? id,
    String? scope,
    String? topicId,
    int? seq,
    String? body,
  }) => MessageSearchRow(
    id: id ?? this.id,
    scope: scope ?? this.scope,
    topicId: topicId ?? this.topicId,
    seq: seq ?? this.seq,
    body: body ?? this.body,
  );
  MessageSearchRow copyWithCompanion(MessageSearchCompanion data) {
    return MessageSearchRow(
      id: data.id.present ? data.id.value : this.id,
      scope: data.scope.present ? data.scope.value : this.scope,
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
      seq: data.seq.present ? data.seq.value : this.seq,
      body: data.body.present ? data.body.value : this.body,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageSearchRow(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('topicId: $topicId, ')
          ..write('seq: $seq, ')
          ..write('body: $body')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, scope, topicId, seq, body);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageSearchRow &&
          other.id == this.id &&
          other.scope == this.scope &&
          other.topicId == this.topicId &&
          other.seq == this.seq &&
          other.body == this.body);
}

class MessageSearchCompanion extends UpdateCompanion<MessageSearchRow> {
  final Value<int> id;
  final Value<String> scope;
  final Value<String> topicId;
  final Value<int> seq;
  final Value<String> body;
  const MessageSearchCompanion({
    this.id = const Value.absent(),
    this.scope = const Value.absent(),
    this.topicId = const Value.absent(),
    this.seq = const Value.absent(),
    this.body = const Value.absent(),
  });
  MessageSearchCompanion.insert({
    this.id = const Value.absent(),
    required String scope,
    required String topicId,
    required int seq,
    required String body,
  }) : scope = Value(scope),
       topicId = Value(topicId),
       seq = Value(seq),
       body = Value(body);
  static Insertable<MessageSearchRow> custom({
    Expression<int>? id,
    Expression<String>? scope,
    Expression<String>? topicId,
    Expression<int>? seq,
    Expression<String>? body,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scope != null) 'scope': scope,
      if (topicId != null) 'topic_id': topicId,
      if (seq != null) 'seq': seq,
      if (body != null) 'body': body,
    });
  }

  MessageSearchCompanion copyWith({
    Value<int>? id,
    Value<String>? scope,
    Value<String>? topicId,
    Value<int>? seq,
    Value<String>? body,
  }) {
    return MessageSearchCompanion(
      id: id ?? this.id,
      scope: scope ?? this.scope,
      topicId: topicId ?? this.topicId,
      seq: seq ?? this.seq,
      body: body ?? this.body,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (topicId.present) {
      map['topic_id'] = Variable<String>(topicId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageSearchCompanion(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('topicId: $topicId, ')
          ..write('seq: $seq, ')
          ..write('body: $body')
          ..write(')'))
        .toString();
  }
}

class $MediaEntriesTable extends MediaEntries
    with TableInfo<$MediaEntriesTable, MediaEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topicIdMeta = const VerificationMeta(
    'topicId',
  );
  @override
  late final GeneratedColumn<String> topicId = GeneratedColumn<String>(
    'topic_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIndexMeta = const VerificationMeta(
    'entityIndex',
  );
  @override
  late final GeneratedColumn<int> entityIndex = GeneratedColumn<int>(
    'entity_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
    'sender_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isInlineMeta = const VerificationMeta(
    'isInline',
  );
  @override
  late final GeneratedColumn<bool> isInline = GeneratedColumn<bool>(
    'is_inline',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_inline" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    scope,
    topicId,
    seq,
    entityIndex,
    clientId,
    type,
    senderId,
    createdAtMs,
    data,
    isInline,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('topic_id')) {
      context.handle(
        _topicIdMeta,
        topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_topicIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('entity_index')) {
      context.handle(
        _entityIndexMeta,
        entityIndex.isAcceptableOrUnknown(
          data['entity_index']!,
          _entityIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_entityIndexMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('is_inline')) {
      context.handle(
        _isInlineMeta,
        isInline.isAcceptableOrUnknown(data['is_inline']!, _isInlineMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope, topicId, seq, entityIndex};
  @override
  MediaEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaEntryRow(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      topicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      entityIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entity_index'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_id'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      isInline: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_inline'],
      )!,
    );
  }

  @override
  $MediaEntriesTable createAlias(String alias) {
    return $MediaEntriesTable(attachedDatabase, alias);
  }
}

class MediaEntryRow extends DataClass implements Insertable<MediaEntryRow> {
  final String scope;
  final String topicId;
  final int seq;
  final int entityIndex;
  final String clientId;
  final String type;
  final String senderId;
  final int createdAtMs;
  final String data;
  final bool isInline;
  const MediaEntryRow({
    required this.scope,
    required this.topicId,
    required this.seq,
    required this.entityIndex,
    required this.clientId,
    required this.type,
    required this.senderId,
    required this.createdAtMs,
    required this.data,
    required this.isInline,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['topic_id'] = Variable<String>(topicId);
    map['seq'] = Variable<int>(seq);
    map['entity_index'] = Variable<int>(entityIndex);
    map['client_id'] = Variable<String>(clientId);
    map['type'] = Variable<String>(type);
    map['sender_id'] = Variable<String>(senderId);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['data'] = Variable<String>(data);
    map['is_inline'] = Variable<bool>(isInline);
    return map;
  }

  MediaEntriesCompanion toCompanion(bool nullToAbsent) {
    return MediaEntriesCompanion(
      scope: Value(scope),
      topicId: Value(topicId),
      seq: Value(seq),
      entityIndex: Value(entityIndex),
      clientId: Value(clientId),
      type: Value(type),
      senderId: Value(senderId),
      createdAtMs: Value(createdAtMs),
      data: Value(data),
      isInline: Value(isInline),
    );
  }

  factory MediaEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaEntryRow(
      scope: serializer.fromJson<String>(json['scope']),
      topicId: serializer.fromJson<String>(json['topicId']),
      seq: serializer.fromJson<int>(json['seq']),
      entityIndex: serializer.fromJson<int>(json['entityIndex']),
      clientId: serializer.fromJson<String>(json['clientId']),
      type: serializer.fromJson<String>(json['type']),
      senderId: serializer.fromJson<String>(json['senderId']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      data: serializer.fromJson<String>(json['data']),
      isInline: serializer.fromJson<bool>(json['isInline']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'topicId': serializer.toJson<String>(topicId),
      'seq': serializer.toJson<int>(seq),
      'entityIndex': serializer.toJson<int>(entityIndex),
      'clientId': serializer.toJson<String>(clientId),
      'type': serializer.toJson<String>(type),
      'senderId': serializer.toJson<String>(senderId),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'data': serializer.toJson<String>(data),
      'isInline': serializer.toJson<bool>(isInline),
    };
  }

  MediaEntryRow copyWith({
    String? scope,
    String? topicId,
    int? seq,
    int? entityIndex,
    String? clientId,
    String? type,
    String? senderId,
    int? createdAtMs,
    String? data,
    bool? isInline,
  }) => MediaEntryRow(
    scope: scope ?? this.scope,
    topicId: topicId ?? this.topicId,
    seq: seq ?? this.seq,
    entityIndex: entityIndex ?? this.entityIndex,
    clientId: clientId ?? this.clientId,
    type: type ?? this.type,
    senderId: senderId ?? this.senderId,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    data: data ?? this.data,
    isInline: isInline ?? this.isInline,
  );
  MediaEntryRow copyWithCompanion(MediaEntriesCompanion data) {
    return MediaEntryRow(
      scope: data.scope.present ? data.scope.value : this.scope,
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
      seq: data.seq.present ? data.seq.value : this.seq,
      entityIndex: data.entityIndex.present
          ? data.entityIndex.value
          : this.entityIndex,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      type: data.type.present ? data.type.value : this.type,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      data: data.data.present ? data.data.value : this.data,
      isInline: data.isInline.present ? data.isInline.value : this.isInline,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaEntryRow(')
          ..write('scope: $scope, ')
          ..write('topicId: $topicId, ')
          ..write('seq: $seq, ')
          ..write('entityIndex: $entityIndex, ')
          ..write('clientId: $clientId, ')
          ..write('type: $type, ')
          ..write('senderId: $senderId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('data: $data, ')
          ..write('isInline: $isInline')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scope,
    topicId,
    seq,
    entityIndex,
    clientId,
    type,
    senderId,
    createdAtMs,
    data,
    isInline,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaEntryRow &&
          other.scope == this.scope &&
          other.topicId == this.topicId &&
          other.seq == this.seq &&
          other.entityIndex == this.entityIndex &&
          other.clientId == this.clientId &&
          other.type == this.type &&
          other.senderId == this.senderId &&
          other.createdAtMs == this.createdAtMs &&
          other.data == this.data &&
          other.isInline == this.isInline);
}

class MediaEntriesCompanion extends UpdateCompanion<MediaEntryRow> {
  final Value<String> scope;
  final Value<String> topicId;
  final Value<int> seq;
  final Value<int> entityIndex;
  final Value<String> clientId;
  final Value<String> type;
  final Value<String> senderId;
  final Value<int> createdAtMs;
  final Value<String> data;
  final Value<bool> isInline;
  final Value<int> rowid;
  const MediaEntriesCompanion({
    this.scope = const Value.absent(),
    this.topicId = const Value.absent(),
    this.seq = const Value.absent(),
    this.entityIndex = const Value.absent(),
    this.clientId = const Value.absent(),
    this.type = const Value.absent(),
    this.senderId = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.data = const Value.absent(),
    this.isInline = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaEntriesCompanion.insert({
    required String scope,
    required String topicId,
    required int seq,
    required int entityIndex,
    required String clientId,
    required String type,
    required String senderId,
    required int createdAtMs,
    required String data,
    this.isInline = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scope = Value(scope),
       topicId = Value(topicId),
       seq = Value(seq),
       entityIndex = Value(entityIndex),
       clientId = Value(clientId),
       type = Value(type),
       senderId = Value(senderId),
       createdAtMs = Value(createdAtMs),
       data = Value(data);
  static Insertable<MediaEntryRow> custom({
    Expression<String>? scope,
    Expression<String>? topicId,
    Expression<int>? seq,
    Expression<int>? entityIndex,
    Expression<String>? clientId,
    Expression<String>? type,
    Expression<String>? senderId,
    Expression<int>? createdAtMs,
    Expression<String>? data,
    Expression<bool>? isInline,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (topicId != null) 'topic_id': topicId,
      if (seq != null) 'seq': seq,
      if (entityIndex != null) 'entity_index': entityIndex,
      if (clientId != null) 'client_id': clientId,
      if (type != null) 'type': type,
      if (senderId != null) 'sender_id': senderId,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (data != null) 'data': data,
      if (isInline != null) 'is_inline': isInline,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaEntriesCompanion copyWith({
    Value<String>? scope,
    Value<String>? topicId,
    Value<int>? seq,
    Value<int>? entityIndex,
    Value<String>? clientId,
    Value<String>? type,
    Value<String>? senderId,
    Value<int>? createdAtMs,
    Value<String>? data,
    Value<bool>? isInline,
    Value<int>? rowid,
  }) {
    return MediaEntriesCompanion(
      scope: scope ?? this.scope,
      topicId: topicId ?? this.topicId,
      seq: seq ?? this.seq,
      entityIndex: entityIndex ?? this.entityIndex,
      clientId: clientId ?? this.clientId,
      type: type ?? this.type,
      senderId: senderId ?? this.senderId,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      data: data ?? this.data,
      isInline: isInline ?? this.isInline,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (topicId.present) {
      map['topic_id'] = Variable<String>(topicId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (entityIndex.present) {
      map['entity_index'] = Variable<int>(entityIndex.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (isInline.present) {
      map['is_inline'] = Variable<bool>(isInline.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaEntriesCompanion(')
          ..write('scope: $scope, ')
          ..write('topicId: $topicId, ')
          ..write('seq: $seq, ')
          ..write('entityIndex: $entityIndex, ')
          ..write('clientId: $clientId, ')
          ..write('type: $type, ')
          ..write('senderId: $senderId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('data: $data, ')
          ..write('isInline: $isInline, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TopicsTable topics = $TopicsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $OutboxAttachmentsTable outboxAttachments =
      $OutboxAttachmentsTable(this);
  late final $MessageSearchTable messageSearch = $MessageSearchTable(this);
  late final $MediaEntriesTable mediaEntries = $MediaEntriesTable(this);
  late final Index messagesClientId = Index(
    'messages_client_id',
    'CREATE INDEX messages_client_id ON messages (scope, client_id)',
  );
  late final Index mediaCategory = Index(
    'media_category',
    'CREATE INDEX media_category ON media_entries (scope, topic_id, type, seq, entity_index)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    topics,
    messages,
    outbox,
    outboxAttachments,
    messageSearch,
    mediaEntries,
    messagesClientId,
    mediaCategory,
  ];
}

typedef $$TopicsTableCreateCompanionBuilder =
    TopicsCompanion Function({
      required String scope,
      required String id,
      required String title,
      Value<String?> avatarRef,
      Value<bool> online,
      Value<bool> isGroup,
      Value<int> serverSeq,
      Value<int> readSeq,
      Value<int> recvSeq,
      Value<int> peerReadSeq,
      Value<int> peerRecvSeq,
      Value<int> lastMessageSeq,
      Value<int?> lastMessageAt,
      Value<String> lastPreview,
      Value<String> draft,
      Value<int> deletionId,
      Value<String> coverage,
      Value<String> deletedRanges,
      Value<int> rowid,
    });
typedef $$TopicsTableUpdateCompanionBuilder =
    TopicsCompanion Function({
      Value<String> scope,
      Value<String> id,
      Value<String> title,
      Value<String?> avatarRef,
      Value<bool> online,
      Value<bool> isGroup,
      Value<int> serverSeq,
      Value<int> readSeq,
      Value<int> recvSeq,
      Value<int> peerReadSeq,
      Value<int> peerRecvSeq,
      Value<int> lastMessageSeq,
      Value<int?> lastMessageAt,
      Value<String> lastPreview,
      Value<String> draft,
      Value<int> deletionId,
      Value<String> coverage,
      Value<String> deletedRanges,
      Value<int> rowid,
    });

class $$TopicsTableFilterComposer
    extends Composer<_$AppDatabase, $TopicsTable> {
  $$TopicsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarRef => $composableBuilder(
    column: $table.avatarRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get online => $composableBuilder(
    column: $table.online,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isGroup => $composableBuilder(
    column: $table.isGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get readSeq => $composableBuilder(
    column: $table.readSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recvSeq => $composableBuilder(
    column: $table.recvSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get peerReadSeq => $composableBuilder(
    column: $table.peerReadSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get peerRecvSeq => $composableBuilder(
    column: $table.peerRecvSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastMessageSeq => $composableBuilder(
    column: $table.lastMessageSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastPreview => $composableBuilder(
    column: $table.lastPreview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get draft => $composableBuilder(
    column: $table.draft,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletionId => $composableBuilder(
    column: $table.deletionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverage => $composableBuilder(
    column: $table.coverage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedRanges => $composableBuilder(
    column: $table.deletedRanges,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TopicsTableOrderingComposer
    extends Composer<_$AppDatabase, $TopicsTable> {
  $$TopicsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarRef => $composableBuilder(
    column: $table.avatarRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get online => $composableBuilder(
    column: $table.online,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isGroup => $composableBuilder(
    column: $table.isGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get readSeq => $composableBuilder(
    column: $table.readSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recvSeq => $composableBuilder(
    column: $table.recvSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get peerReadSeq => $composableBuilder(
    column: $table.peerReadSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get peerRecvSeq => $composableBuilder(
    column: $table.peerRecvSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastMessageSeq => $composableBuilder(
    column: $table.lastMessageSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastPreview => $composableBuilder(
    column: $table.lastPreview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get draft => $composableBuilder(
    column: $table.draft,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletionId => $composableBuilder(
    column: $table.deletionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverage => $composableBuilder(
    column: $table.coverage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedRanges => $composableBuilder(
    column: $table.deletedRanges,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TopicsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TopicsTable> {
  $$TopicsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get avatarRef =>
      $composableBuilder(column: $table.avatarRef, builder: (column) => column);

  GeneratedColumn<bool> get online =>
      $composableBuilder(column: $table.online, builder: (column) => column);

  GeneratedColumn<bool> get isGroup =>
      $composableBuilder(column: $table.isGroup, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumn<int> get readSeq =>
      $composableBuilder(column: $table.readSeq, builder: (column) => column);

  GeneratedColumn<int> get recvSeq =>
      $composableBuilder(column: $table.recvSeq, builder: (column) => column);

  GeneratedColumn<int> get peerReadSeq => $composableBuilder(
    column: $table.peerReadSeq,
    builder: (column) => column,
  );

  GeneratedColumn<int> get peerRecvSeq => $composableBuilder(
    column: $table.peerRecvSeq,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastMessageSeq => $composableBuilder(
    column: $table.lastMessageSeq,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastPreview => $composableBuilder(
    column: $table.lastPreview,
    builder: (column) => column,
  );

  GeneratedColumn<String> get draft =>
      $composableBuilder(column: $table.draft, builder: (column) => column);

  GeneratedColumn<int> get deletionId => $composableBuilder(
    column: $table.deletionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverage =>
      $composableBuilder(column: $table.coverage, builder: (column) => column);

  GeneratedColumn<String> get deletedRanges => $composableBuilder(
    column: $table.deletedRanges,
    builder: (column) => column,
  );
}

class $$TopicsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TopicsTable,
          TopicRow,
          $$TopicsTableFilterComposer,
          $$TopicsTableOrderingComposer,
          $$TopicsTableAnnotationComposer,
          $$TopicsTableCreateCompanionBuilder,
          $$TopicsTableUpdateCompanionBuilder,
          (TopicRow, BaseReferences<_$AppDatabase, $TopicsTable, TopicRow>),
          TopicRow,
          PrefetchHooks Function()
        > {
  $$TopicsTableTableManager(_$AppDatabase db, $TopicsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TopicsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TopicsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TopicsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> avatarRef = const Value.absent(),
                Value<bool> online = const Value.absent(),
                Value<bool> isGroup = const Value.absent(),
                Value<int> serverSeq = const Value.absent(),
                Value<int> readSeq = const Value.absent(),
                Value<int> recvSeq = const Value.absent(),
                Value<int> peerReadSeq = const Value.absent(),
                Value<int> peerRecvSeq = const Value.absent(),
                Value<int> lastMessageSeq = const Value.absent(),
                Value<int?> lastMessageAt = const Value.absent(),
                Value<String> lastPreview = const Value.absent(),
                Value<String> draft = const Value.absent(),
                Value<int> deletionId = const Value.absent(),
                Value<String> coverage = const Value.absent(),
                Value<String> deletedRanges = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TopicsCompanion(
                scope: scope,
                id: id,
                title: title,
                avatarRef: avatarRef,
                online: online,
                isGroup: isGroup,
                serverSeq: serverSeq,
                readSeq: readSeq,
                recvSeq: recvSeq,
                peerReadSeq: peerReadSeq,
                peerRecvSeq: peerRecvSeq,
                lastMessageSeq: lastMessageSeq,
                lastMessageAt: lastMessageAt,
                lastPreview: lastPreview,
                draft: draft,
                deletionId: deletionId,
                coverage: coverage,
                deletedRanges: deletedRanges,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                required String id,
                required String title,
                Value<String?> avatarRef = const Value.absent(),
                Value<bool> online = const Value.absent(),
                Value<bool> isGroup = const Value.absent(),
                Value<int> serverSeq = const Value.absent(),
                Value<int> readSeq = const Value.absent(),
                Value<int> recvSeq = const Value.absent(),
                Value<int> peerReadSeq = const Value.absent(),
                Value<int> peerRecvSeq = const Value.absent(),
                Value<int> lastMessageSeq = const Value.absent(),
                Value<int?> lastMessageAt = const Value.absent(),
                Value<String> lastPreview = const Value.absent(),
                Value<String> draft = const Value.absent(),
                Value<int> deletionId = const Value.absent(),
                Value<String> coverage = const Value.absent(),
                Value<String> deletedRanges = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TopicsCompanion.insert(
                scope: scope,
                id: id,
                title: title,
                avatarRef: avatarRef,
                online: online,
                isGroup: isGroup,
                serverSeq: serverSeq,
                readSeq: readSeq,
                recvSeq: recvSeq,
                peerReadSeq: peerReadSeq,
                peerRecvSeq: peerRecvSeq,
                lastMessageSeq: lastMessageSeq,
                lastMessageAt: lastMessageAt,
                lastPreview: lastPreview,
                draft: draft,
                deletionId: deletionId,
                coverage: coverage,
                deletedRanges: deletedRanges,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TopicsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TopicsTable,
      TopicRow,
      $$TopicsTableFilterComposer,
      $$TopicsTableOrderingComposer,
      $$TopicsTableAnnotationComposer,
      $$TopicsTableCreateCompanionBuilder,
      $$TopicsTableUpdateCompanionBuilder,
      (TopicRow, BaseReferences<_$AppDatabase, $TopicsTable, TopicRow>),
      TopicRow,
      PrefetchHooks Function()
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      required String scope,
      required String topicId,
      required int seq,
      required String clientId,
      Value<int> localSeq,
      required String senderId,
      required int createdAtMs,
      required String content,
      Value<String> head,
      Value<int> delivery,
      Value<bool> hidden,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> scope,
      Value<String> topicId,
      Value<int> seq,
      Value<String> clientId,
      Value<int> localSeq,
      Value<String> senderId,
      Value<int> createdAtMs,
      Value<String> content,
      Value<String> head,
      Value<int> delivery,
      Value<bool> hidden,
      Value<bool> deleted,
      Value<int> rowid,
    });

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localSeq => $composableBuilder(
    column: $table.localSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get head => $composableBuilder(
    column: $table.head,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get delivery => $composableBuilder(
    column: $table.delivery,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localSeq => $composableBuilder(
    column: $table.localSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get head => $composableBuilder(
    column: $table.head,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get delivery => $composableBuilder(
    column: $table.delivery,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get topicId =>
      $composableBuilder(column: $table.topicId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<int> get localSeq =>
      $composableBuilder(column: $table.localSeq, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get head =>
      $composableBuilder(column: $table.head, builder: (column) => column);

  GeneratedColumn<int> get delivery =>
      $composableBuilder(column: $table.delivery, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          MessageRow,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (
            MessageRow,
            BaseReferences<_$AppDatabase, $MessagesTable, MessageRow>,
          ),
          MessageRow,
          PrefetchHooks Function()
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<String> topicId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> clientId = const Value.absent(),
                Value<int> localSeq = const Value.absent(),
                Value<String> senderId = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> head = const Value.absent(),
                Value<int> delivery = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                scope: scope,
                topicId: topicId,
                seq: seq,
                clientId: clientId,
                localSeq: localSeq,
                senderId: senderId,
                createdAtMs: createdAtMs,
                content: content,
                head: head,
                delivery: delivery,
                hidden: hidden,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                required String topicId,
                required int seq,
                required String clientId,
                Value<int> localSeq = const Value.absent(),
                required String senderId,
                required int createdAtMs,
                required String content,
                Value<String> head = const Value.absent(),
                Value<int> delivery = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                scope: scope,
                topicId: topicId,
                seq: seq,
                clientId: clientId,
                localSeq: localSeq,
                senderId: senderId,
                createdAtMs: createdAtMs,
                content: content,
                head: head,
                delivery: delivery,
                hidden: hidden,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      MessageRow,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (MessageRow, BaseReferences<_$AppDatabase, $MessagesTable, MessageRow>),
      MessageRow,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      required String scope,
      required String clientId,
      required String topicId,
      required int localSeq,
      Value<int> afterSeq,
      Value<int> attempts,
      Value<int> nextRetryAt,
      Value<bool> ambiguous,
      Value<String?> error,
      Value<int> rowid,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<String> scope,
      Value<String> clientId,
      Value<String> topicId,
      Value<int> localSeq,
      Value<int> afterSeq,
      Value<int> attempts,
      Value<int> nextRetryAt,
      Value<bool> ambiguous,
      Value<String?> error,
      Value<int> rowid,
    });

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localSeq => $composableBuilder(
    column: $table.localSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get afterSeq => $composableBuilder(
    column: $table.afterSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ambiguous => $composableBuilder(
    column: $table.ambiguous,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localSeq => $composableBuilder(
    column: $table.localSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get afterSeq => $composableBuilder(
    column: $table.afterSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ambiguous => $composableBuilder(
    column: $table.ambiguous,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<String> get topicId =>
      $composableBuilder(column: $table.topicId, builder: (column) => column);

  GeneratedColumn<int> get localSeq =>
      $composableBuilder(column: $table.localSeq, builder: (column) => column);

  GeneratedColumn<int> get afterSeq =>
      $composableBuilder(column: $table.afterSeq, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get ambiguous =>
      $composableBuilder(column: $table.ambiguous, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxRow,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<String> clientId = const Value.absent(),
                Value<String> topicId = const Value.absent(),
                Value<int> localSeq = const Value.absent(),
                Value<int> afterSeq = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> nextRetryAt = const Value.absent(),
                Value<bool> ambiguous = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion(
                scope: scope,
                clientId: clientId,
                topicId: topicId,
                localSeq: localSeq,
                afterSeq: afterSeq,
                attempts: attempts,
                nextRetryAt: nextRetryAt,
                ambiguous: ambiguous,
                error: error,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                required String clientId,
                required String topicId,
                required int localSeq,
                Value<int> afterSeq = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> nextRetryAt = const Value.absent(),
                Value<bool> ambiguous = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion.insert(
                scope: scope,
                clientId: clientId,
                topicId: topicId,
                localSeq: localSeq,
                afterSeq: afterSeq,
                attempts: attempts,
                nextRetryAt: nextRetryAt,
                ambiguous: ambiguous,
                error: error,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxRow,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$OutboxAttachmentsTableCreateCompanionBuilder =
    OutboxAttachmentsCompanion Function({
      required String scope,
      required String clientId,
      required int entityIndex,
      required Uint8List bytes,
      required String name,
      required String mime,
      Value<String?> remoteRef,
      Value<int> rowid,
    });
typedef $$OutboxAttachmentsTableUpdateCompanionBuilder =
    OutboxAttachmentsCompanion Function({
      Value<String> scope,
      Value<String> clientId,
      Value<int> entityIndex,
      Value<Uint8List> bytes,
      Value<String> name,
      Value<String> mime,
      Value<String?> remoteRef,
      Value<int> rowid,
    });

class $$OutboxAttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxAttachmentsTable> {
  $$OutboxAttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get entityIndex => $composableBuilder(
    column: $table.entityIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteRef => $composableBuilder(
    column: $table.remoteRef,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxAttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxAttachmentsTable> {
  $$OutboxAttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entityIndex => $composableBuilder(
    column: $table.entityIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteRef => $composableBuilder(
    column: $table.remoteRef,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxAttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxAttachmentsTable> {
  $$OutboxAttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<int> get entityIndex => $composableBuilder(
    column: $table.entityIndex,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<String> get remoteRef =>
      $composableBuilder(column: $table.remoteRef, builder: (column) => column);
}

class $$OutboxAttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxAttachmentsTable,
          OutboxAttachmentRow,
          $$OutboxAttachmentsTableFilterComposer,
          $$OutboxAttachmentsTableOrderingComposer,
          $$OutboxAttachmentsTableAnnotationComposer,
          $$OutboxAttachmentsTableCreateCompanionBuilder,
          $$OutboxAttachmentsTableUpdateCompanionBuilder,
          (
            OutboxAttachmentRow,
            BaseReferences<
              _$AppDatabase,
              $OutboxAttachmentsTable,
              OutboxAttachmentRow
            >,
          ),
          OutboxAttachmentRow,
          PrefetchHooks Function()
        > {
  $$OutboxAttachmentsTableTableManager(
    _$AppDatabase db,
    $OutboxAttachmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxAttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxAttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxAttachmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<String> clientId = const Value.absent(),
                Value<int> entityIndex = const Value.absent(),
                Value<Uint8List> bytes = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> mime = const Value.absent(),
                Value<String?> remoteRef = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxAttachmentsCompanion(
                scope: scope,
                clientId: clientId,
                entityIndex: entityIndex,
                bytes: bytes,
                name: name,
                mime: mime,
                remoteRef: remoteRef,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                required String clientId,
                required int entityIndex,
                required Uint8List bytes,
                required String name,
                required String mime,
                Value<String?> remoteRef = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxAttachmentsCompanion.insert(
                scope: scope,
                clientId: clientId,
                entityIndex: entityIndex,
                bytes: bytes,
                name: name,
                mime: mime,
                remoteRef: remoteRef,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxAttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxAttachmentsTable,
      OutboxAttachmentRow,
      $$OutboxAttachmentsTableFilterComposer,
      $$OutboxAttachmentsTableOrderingComposer,
      $$OutboxAttachmentsTableAnnotationComposer,
      $$OutboxAttachmentsTableCreateCompanionBuilder,
      $$OutboxAttachmentsTableUpdateCompanionBuilder,
      (
        OutboxAttachmentRow,
        BaseReferences<
          _$AppDatabase,
          $OutboxAttachmentsTable,
          OutboxAttachmentRow
        >,
      ),
      OutboxAttachmentRow,
      PrefetchHooks Function()
    >;
typedef $$MessageSearchTableCreateCompanionBuilder =
    MessageSearchCompanion Function({
      Value<int> id,
      required String scope,
      required String topicId,
      required int seq,
      required String body,
    });
typedef $$MessageSearchTableUpdateCompanionBuilder =
    MessageSearchCompanion Function({
      Value<int> id,
      Value<String> scope,
      Value<String> topicId,
      Value<int> seq,
      Value<String> body,
    });

class $$MessageSearchTableFilterComposer
    extends Composer<_$AppDatabase, $MessageSearchTable> {
  $$MessageSearchTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessageSearchTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageSearchTable> {
  $$MessageSearchTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessageSearchTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageSearchTable> {
  $$MessageSearchTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get topicId =>
      $composableBuilder(column: $table.topicId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);
}

class $$MessageSearchTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessageSearchTable,
          MessageSearchRow,
          $$MessageSearchTableFilterComposer,
          $$MessageSearchTableOrderingComposer,
          $$MessageSearchTableAnnotationComposer,
          $$MessageSearchTableCreateCompanionBuilder,
          $$MessageSearchTableUpdateCompanionBuilder,
          (
            MessageSearchRow,
            BaseReferences<
              _$AppDatabase,
              $MessageSearchTable,
              MessageSearchRow
            >,
          ),
          MessageSearchRow,
          PrefetchHooks Function()
        > {
  $$MessageSearchTableTableManager(_$AppDatabase db, $MessageSearchTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageSearchTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageSearchTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageSearchTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> topicId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> body = const Value.absent(),
              }) => MessageSearchCompanion(
                id: id,
                scope: scope,
                topicId: topicId,
                seq: seq,
                body: body,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String scope,
                required String topicId,
                required int seq,
                required String body,
              }) => MessageSearchCompanion.insert(
                id: id,
                scope: scope,
                topicId: topicId,
                seq: seq,
                body: body,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessageSearchTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessageSearchTable,
      MessageSearchRow,
      $$MessageSearchTableFilterComposer,
      $$MessageSearchTableOrderingComposer,
      $$MessageSearchTableAnnotationComposer,
      $$MessageSearchTableCreateCompanionBuilder,
      $$MessageSearchTableUpdateCompanionBuilder,
      (
        MessageSearchRow,
        BaseReferences<_$AppDatabase, $MessageSearchTable, MessageSearchRow>,
      ),
      MessageSearchRow,
      PrefetchHooks Function()
    >;
typedef $$MediaEntriesTableCreateCompanionBuilder =
    MediaEntriesCompanion Function({
      required String scope,
      required String topicId,
      required int seq,
      required int entityIndex,
      required String clientId,
      required String type,
      required String senderId,
      required int createdAtMs,
      required String data,
      Value<bool> isInline,
      Value<int> rowid,
    });
typedef $$MediaEntriesTableUpdateCompanionBuilder =
    MediaEntriesCompanion Function({
      Value<String> scope,
      Value<String> topicId,
      Value<int> seq,
      Value<int> entityIndex,
      Value<String> clientId,
      Value<String> type,
      Value<String> senderId,
      Value<int> createdAtMs,
      Value<String> data,
      Value<bool> isInline,
      Value<int> rowid,
    });

class $$MediaEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MediaEntriesTable> {
  $$MediaEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get entityIndex => $composableBuilder(
    column: $table.entityIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isInline => $composableBuilder(
    column: $table.isInline,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MediaEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaEntriesTable> {
  $$MediaEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entityIndex => $composableBuilder(
    column: $table.entityIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isInline => $composableBuilder(
    column: $table.isInline,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MediaEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaEntriesTable> {
  $$MediaEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get topicId =>
      $composableBuilder(column: $table.topicId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<int> get entityIndex => $composableBuilder(
    column: $table.entityIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<bool> get isInline =>
      $composableBuilder(column: $table.isInline, builder: (column) => column);
}

class $$MediaEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MediaEntriesTable,
          MediaEntryRow,
          $$MediaEntriesTableFilterComposer,
          $$MediaEntriesTableOrderingComposer,
          $$MediaEntriesTableAnnotationComposer,
          $$MediaEntriesTableCreateCompanionBuilder,
          $$MediaEntriesTableUpdateCompanionBuilder,
          (
            MediaEntryRow,
            BaseReferences<_$AppDatabase, $MediaEntriesTable, MediaEntryRow>,
          ),
          MediaEntryRow,
          PrefetchHooks Function()
        > {
  $$MediaEntriesTableTableManager(_$AppDatabase db, $MediaEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<String> topicId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<int> entityIndex = const Value.absent(),
                Value<String> clientId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> senderId = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<bool> isInline = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaEntriesCompanion(
                scope: scope,
                topicId: topicId,
                seq: seq,
                entityIndex: entityIndex,
                clientId: clientId,
                type: type,
                senderId: senderId,
                createdAtMs: createdAtMs,
                data: data,
                isInline: isInline,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                required String topicId,
                required int seq,
                required int entityIndex,
                required String clientId,
                required String type,
                required String senderId,
                required int createdAtMs,
                required String data,
                Value<bool> isInline = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaEntriesCompanion.insert(
                scope: scope,
                topicId: topicId,
                seq: seq,
                entityIndex: entityIndex,
                clientId: clientId,
                type: type,
                senderId: senderId,
                createdAtMs: createdAtMs,
                data: data,
                isInline: isInline,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MediaEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MediaEntriesTable,
      MediaEntryRow,
      $$MediaEntriesTableFilterComposer,
      $$MediaEntriesTableOrderingComposer,
      $$MediaEntriesTableAnnotationComposer,
      $$MediaEntriesTableCreateCompanionBuilder,
      $$MediaEntriesTableUpdateCompanionBuilder,
      (
        MediaEntryRow,
        BaseReferences<_$AppDatabase, $MediaEntriesTable, MediaEntryRow>,
      ),
      MediaEntryRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TopicsTableTableManager get topics =>
      $$TopicsTableTableManager(_db, _db.topics);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$OutboxAttachmentsTableTableManager get outboxAttachments =>
      $$OutboxAttachmentsTableTableManager(_db, _db.outboxAttachments);
  $$MessageSearchTableTableManager get messageSearch =>
      $$MessageSearchTableTableManager(_db, _db.messageSearch);
  $$MediaEntriesTableTableManager get mediaEntries =>
      $$MediaEntriesTableTableManager(_db, _db.mediaEntries);
}
