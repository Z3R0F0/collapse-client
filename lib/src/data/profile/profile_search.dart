part of 'profile_repository.dart';

extension _ProfileSearch on ProfileRepository {
  Future<List<PeerProfile>> _search(String username) {
    final query = username.trim();
    if (query.isEmpty) return Future.value([]);
    final epoch = _epoch;
    // fnd has one mutable query per session: keep set + get indivisible.
    final operation = (_searchTail ?? Future<void>.value()).then((_) async {
      _checkEpoch(epoch);
      _requireSession();
      await gateway.attach('fnd');
      _checkEpoch(epoch);
      _requireSession();
      await gateway.setMeta('fnd', {
        'desc': {'public': 'basic:$query'},
      });
      _checkEpoch(epoch);
      _requireSession();
      final results = await gateway.subscriptions(topic: 'fnd');
      _checkEpoch(epoch);
      return results
          .map((row) {
            final id = (row['topic'] ?? row['user'])?.toString() ?? '';
            return PeerProfile.fromPublic(
              id,
              Map<String, dynamic>.from(row['public'] as Map? ?? {}),
            );
          })
          .where(
            (profile) =>
                profile.id.startsWith('usr') && profile.id != gateway.userId,
          )
          .toList();
    });
    _searchTail = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }
}
