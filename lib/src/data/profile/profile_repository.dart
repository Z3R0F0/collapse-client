import 'dart:typed_data';
import 'package:collapse_tinode/tinode.dart';

import 'peer_profile.dart';

export 'peer_profile.dart';

part 'profile_search.dart';

class ProfileRepository {
  ProfileRepository(this.gateway);
  final TinodeGateway gateway;
  final _cache = <String, PeerProfile>{};
  final _pending = <String, Future<PeerProfile>>{};
  int _epoch = 0;
  int get accountGeneration => _epoch;
  Future<void>? _searchTail;
  void clear() {
    _epoch++;
    _cache.clear();
    _pending.clear();
  }

  Future<PeerProfile> get(String id, {bool refresh = false}) async {
    if (!refresh && _cache.containsKey(id)) return _cache[id]!;
    if (_pending.containsKey(id)) return _pending[id]!;
    final future = _fetch(id, _epoch);
    _pending[id] = future;
    try {
      return await future;
    } finally {
      if (identical(_pending[id], future)) _pending.remove(id);
    }
  }

  void _checkEpoch(int epoch) {
    if (epoch != _epoch) throw StateError('Account changed');
  }

  void _requireSession() {
    if (!gateway.connected || gateway.userId == null) {
      throw const TinodeException(0, 'No authenticated connection');
    }
  }

  Future<PeerProfile> _fetch(String id, int epoch) async {
    try {
      _requireSession();
      final desc = await gateway.description(id == gateway.userId ? 'me' : id);
      _checkEpoch(epoch);
      final acs = desc['acs'] as Map? ?? {};
      final mode =
          acs['mode']?.toString() ??
          (acs['want']?.toString() ?? '')
              .split('')
              .where((flag) => (acs['given']?.toString() ?? '').contains(flag))
              .join();
      final profile = PeerProfile.fromPublic(
        id,
        Map<String, dynamic>.from(desc['public'] as Map? ?? {}),
        canInvite: mode.contains('S'),
      );
      if (_cache.length >= 100) _cache.remove(_cache.keys.first);
      return _cache[id] = profile;
    } catch (_) {
      _checkEpoch(epoch);
      final cached = _cache[id];
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<List<PeerProfile>> search(String username) => _search(username);

  Future<List<PeerProfile>> members(String topic) async {
    _requireSession();
    final epoch = _epoch;
    await gateway.attach(topic);
    _checkEpoch(epoch);
    _requireSession();
    final rows = await gateway.subscriptions(topic: topic);
    _checkEpoch(epoch);
    return rows
        .where((row) => row['deleted'] == null && row['user'] is String)
        .map(
          (row) => PeerProfile.fromPublic(
            row['user'] as String,
            Map<String, dynamic>.from(row['public'] as Map? ?? {}),
          ),
        )
        .toList();
  }

  Future<PeerProfile> update({
    required String name,
    required String about,
    Uint8List? photo,
    String? photoName,
    String? photoMime,
  }) async {
    _requireSession();
    final id = gateway.userId!;
    final epoch = _epoch;
    final desc = await gateway.description('me');
    _checkEpoch(epoch);
    final public = Map<String, dynamic>.from(desc['public'] as Map? ?? {});
    public.addAll({'fn': name.trim(), 'note': about.trim()});
    if (photo != null) {
      _requireSession();
      final ref = await gateway.upload(
        photo,
        name: photoName!,
        mime: photoMime!,
      );
      _checkEpoch(epoch);
      public['photo'] = {'ref': ref, 'type': photoMime};
    }
    _requireSession();
    final avatar = public['photo'];
    final ref = avatar is Map ? avatar['ref'] : null;
    await gateway.setMeta('me', {
      'desc': {'public': public},
    }, attachments: ref is String && ref.isNotEmpty ? [ref] : const []);
    _checkEpoch(epoch);
    return _cache[id] = PeerProfile.fromPublic(id, public);
  }

  Future<String> createGroup(String name) async {
    _requireSession();
    final epoch = _epoch;
    final ctrl = await gateway.attach(
      'new',
      set: {
        'desc': {
          'public': {'fn': name.trim()},
        },
      },
    );
    _checkEpoch(epoch);
    return ctrl['topic'] as String;
  }

  Future<void> addMember(String topic, String userId) async {
    _requireSession();
    await gateway.setMeta(topic, {
      'sub': {'user': userId.trim(), 'mode': 'JRWPS'},
    });
  }
}
