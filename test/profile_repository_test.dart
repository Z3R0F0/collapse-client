import 'dart:async';
import 'dart:typed_data';

import 'package:collapse/core/theme.dart';
import 'package:collapse/l10n/app_localizations.dart';
import 'package:collapse/src/data/media/media_repository.dart';
import 'package:collapse/src/data/profile/profile_repository.dart';
import 'package:collapse/src/presentation/profile/profile_cubit.dart';
import 'package:collapse/src/presentation/profile/profile_screen.dart';
import 'package:collapse_tinode/tinode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Gateway gateway;
  late ProfileRepository profiles;
  setUp(() {
    gateway = _Gateway()..userId = 'usrMe';
    profiles = ProfileRepository(gateway);
  });
  tearDown(() => gateway.dispose());

  test('profile update retains an existing remote avatar attachment', () async {
    gateway.describe = (_) async => {
      'public': {
        'fn': 'Before',
        'photo': {'ref': '/v0/file/s/old.png', 'type': 'image/png'},
      },
    };
    await profiles.update(name: 'After', about: 'Changed text');
    expect(gateway.attachmentLists.single, ['/v0/file/s/old.png']);
  });

  test('new avatar replaces the attachment used by profile metadata', () async {
    gateway.describe = (_) async => {
      'public': {
        'photo': {'ref': '/v0/file/s/old.png', 'type': 'image/png'},
      },
    };
    final profile = await profiles.update(
      name: 'Me',
      about: '',
      photo: Uint8List.fromList([1, 2, 3]),
      photoName: 'new.png',
      photoMime: 'image/png',
    );
    expect(gateway.attachmentLists.single, ['/v0/file/s/new.png']);
    expect(profile.avatarRef, '/v0/file/s/new.png');
  });

  test(
    'profile operations never send commands before authenticated handshake',
    () async {
      for (final connection in [(false, 'usrMe'), (true, null)]) {
        gateway.ready = connection.$1;
        gateway.userId = connection.$2;
        await expectLater(
          profiles.get('usrMe'),
          throwsA(isA<TinodeException>()),
        );
        await expectLater(
          profiles.search('peer'),
          throwsA(isA<TinodeException>()),
        );
        await expectLater(
          profiles.members('grpGroup'),
          throwsA(isA<TinodeException>()),
        );
        await expectLater(
          profiles.update(name: 'Me', about: ''),
          throwsA(isA<TinodeException>()),
        );
        await expectLater(
          profiles.createGroup('Group'),
          throwsA(isA<TinodeException>()),
        );
        await expectLater(
          profiles.addMember('grpGroup', 'usrPeer'),
          throwsA(isA<TinodeException>()),
        );
      }
      expect(gateway.descriptionCalls, 0);
      expect(gateway.attachCalls, 0);
      expect(gateway.sets, isEmpty);
    },
  );

  test(
    'cached profile survives disconnected refresh without wire commands',
    () async {
      gateway.describe = (_) async => {
        'public': {'fn': 'Cached'},
      };
      await profiles.get('usrMe');
      gateway.ready = false;
      gateway.userId = null;
      expect((await profiles.get('usrMe', refresh: true)).name, 'Cached');
      expect(gateway.descriptionCalls, 1);
    },
  );

  test(
    'old profile Cubit cannot edit or invite after an account switch',
    () async {
      final own = ProfileCubit(profiles, 'usrMe');
      final group = ProfileCubit(profiles, 'grpGroup');
      // Widget disposal happens next frame; block old callbacks immediately.
      profiles.clear();
      gateway.userId = 'usrAnother';
      await own.save('Old picker result', '');
      await group.invite('usrPeer');
      expect(gateway.descriptionCalls, 0);
      expect(gateway.sets, isEmpty);
      await own.close();
      await group.close();
    },
  );

  testWidgets('group profile searches and invites through Cubits', (
    tester,
  ) async {
    gateway.describe = (_) async => {
      'public': {'fn': 'Group'},
      'acs': {'mode': 'JRWPS'},
    };
    gateway.subs = (topic) async => topic == 'fnd'
        ? [
            {
              'topic': 'usrBob',
              'public': {'fn': 'Bob'},
            },
          ]
        : [
            {
              'user': 'usrMe',
              'public': {'fn': 'Me'},
            },
            if (gateway.sets.any((set) => set['sub'] != null))
              {
                'user': 'usrBob',
                'public': {'fn': 'Bob'},
              },
          ];
    final cubit = ProfileCubit(profiles, 'grpGroup');
    await cubit.load();
    await tester.pumpWidget(
      RepositoryProvider<MediaRepository>.value(
        value: _UnusedMedia(),
        child: BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: appTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: ProfileScreen(userId: 'grpGroup', isMe: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-member')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('member-search')), 'bob');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bob'));
    await tester.pumpAndSettle();
    expect(gateway.sets.last, {
      'topic': 'grpGroup',
      'sub': {'user': 'usrBob', 'mode': 'JRWPS'},
    });
    expect(cubit.state.members.map((m) => m.name), ['Me', 'Bob']);
    expect(find.byKey(const Key('member-search')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  });

  test(
    'late old-account fetch cannot cache or clear the new pending fetch',
    () async {
      final oldResponse = Completer<JsonMap>();
      final newResponse = Completer<JsonMap>();
      gateway.describe = (_) => oldResponse.future;
      final old = profiles.get('usrPeer');
      final rejected = expectLater(old, throwsStateError);
      profiles.clear();
      gateway.userId = 'usrAnother';
      gateway.describe = (_) => newResponse.future;
      final current = profiles.get('usrPeer');
      oldResponse.complete({
        'public': {'fn': 'Old'},
      });
      await rejected;
      final same = profiles.get('usrPeer');
      expect(gateway.descriptionCalls, 2);
      newResponse.complete({
        'public': {'fn': 'Current'},
      });
      expect((await current).name, 'Current');
      expect((await same).name, 'Current');
      expect((await profiles.get('usrPeer')).name, 'Current');
      expect(gateway.descriptionCalls, 2);
    },
  );

  test('offline refresh retains only this account cached profile', () async {
    gateway.describe = (_) async => {
      'public': {'fn': 'Cached'},
    };
    await profiles.get('usrPeer');
    gateway.describe = (_) => Future.error(TimeoutException('offline'));
    expect((await profiles.get('usrPeer', refresh: true)).name, 'Cached');
    profiles.clear();
    await expectLater(
      profiles.get('usrPeer'),
      throwsA(isA<TimeoutException>()),
    );
  });

  test(
    'account switch during own-profile read prevents writing another account',
    () async {
      final response = Completer<JsonMap>();
      gateway.describe = (_) => response.future;
      final update = profiles.update(name: 'Old account', about: '');
      final rejected = expectLater(update, throwsStateError);
      profiles.clear();
      gateway.userId = 'usrAnother';
      response.complete({
        'public': {'fn': 'Old'},
      });
      await rejected;
      expect(gateway.sets, isEmpty);
    },
  );

  test('shared fnd searches serialize query update and results', () async {
    final firstResults = Completer<List<JsonMap>>();
    final started = Completer<void>();
    gateway.subs = (_) {
      if (gateway.query == 'basic:alice') {
        started.complete();
        return firstResults.future;
      }
      return Future.value([
        {
          'topic': 'usrBob',
          'public': {'fn': 'Bob'},
        },
      ]);
    };
    final alice = profiles.search('alice');
    final bob = profiles.search('bob');
    await started.future;
    expect(gateway.query, 'basic:alice');
    expect(gateway.sets.length, 1);
    firstResults.complete([
      {
        'topic': 'usrAlice',
        'public': {'fn': 'Alice'},
      },
      {'topic': 'usrMe'},
      {'topic': 'grpNotAContact'},
    ]);
    expect((await alice).single.id, 'usrAlice');
    expect((await bob).single.id, 'usrBob');
    expect(gateway.sets.length, 2);
  });

  test('search queue recovers after a failed lookup', () async {
    gateway.subs = (_) => Future.error(TimeoutException('offline'));
    await expectLater(
      profiles.search('alice'),
      throwsA(isA<TimeoutException>()),
    );
    gateway.subs = (_) async => [
      {
        'user': 'usrBob',
        'public': {'fn': 'Bob'},
      },
    ];
    expect((await profiles.search('bob')).single.name, 'Bob');
  });

  test('queued search cannot run against a replacement account', () async {
    final firstResults = Completer<List<JsonMap>>();
    final started = Completer<void>();
    gateway.subs = (_) {
      started.complete();
      return firstResults.future;
    };
    final first = profiles.search('alice');
    final second = profiles.search('bob');
    final firstRejected = expectLater(first, throwsStateError);
    final secondRejected = expectLater(second, throwsStateError);
    await started.future;
    profiles.clear();
    gateway.userId = 'usrAnother';
    firstResults.complete([]);
    await Future.wait([firstRejected, secondRejected]);
    expect(gateway.sets.length, 1);
  });

  test(
    'group profile uses effective sharing permission and lists live members',
    () async {
      gateway.describe = (_) async => {
        'public': {'fn': 'Group'},
        'acs': {'want': 'JRWPS', 'given': 'JRWPS'},
      };
      gateway.subs = (_) async => [
        {
          'user': 'usrMe',
          'public': {'fn': 'Me'},
        },
        {'user': 'usrOld', 'deleted': '2026-01-01T00:00:00Z'},
        {
          'user': 'usrPeer',
          'public': {'fn': 'Peer'},
        },
      ];
      final cubit = ProfileCubit(profiles, 'grpGroup');
      await cubit.load();
      expect(cubit.state.profile!.isGroup, isTrue);
      expect(cubit.state.profile!.canInvite, isTrue);
      expect(cubit.state.members.map((m) => m.id), ['usrMe', 'usrPeer']);
      await cubit.invite('usrNew');
      expect(gateway.sets.last, {
        'topic': 'grpGroup',
        'sub': {'user': 'usrNew', 'mode': 'JRWPS'},
      });
      await cubit.close();
      gateway.describe = (_) async => {
        'public': {'fn': 'Group'},
        'acs': {'want': 'JRWPS', 'given': 'JRWP'},
      };
      expect(
        (await profiles.get('grpGroup', refresh: true)).canInvite,
        isFalse,
      );
    },
  );
}

class _Gateway extends TinodeGateway {
  _Gateway() : super(endpoint: Uri.parse('http://localhost'), apiKey: 'test');
  Future<JsonMap> Function(String) describe = (_) async => {};
  Future<List<JsonMap>> Function(String) subs = (_) async => [];
  int descriptionCalls = 0;
  int attachCalls = 0;
  bool ready = true;
  @override
  bool get connected => ready;
  String query = '';
  final sets = <JsonMap>[];
  final attachmentLists = <List<String>>[];

  @override
  Future<JsonMap> description(String topic) {
    descriptionCalls++;
    return describe(topic);
  }

  @override
  Future<JsonMap> attach(String topic, {JsonMap? set}) async {
    attachCalls++;
    return {'topic': topic};
  }

  @override
  Future<JsonMap> setMeta(
    String topic,
    JsonMap set, {
    List<String> attachments = const [],
  }) async {
    sets.add({'topic': topic, ...set});
    attachmentLists.add(List.of(attachments));
    if (topic == 'fnd') query = (set['desc'] as Map)['public'] as String;
    return {};
  }

  @override
  Future<List<JsonMap>> subscriptions({String topic = 'me'}) => subs(topic);

  @override
  Future<String> upload(
    Uint8List bytes, {
    required String name,
    required String mime,
  }) async => '/v0/file/s/$name';
}

class _UnusedMedia implements MediaRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
