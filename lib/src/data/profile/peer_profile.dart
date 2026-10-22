class PeerProfile {
  const PeerProfile({
    required this.id,
    required this.name,
    this.about = '',
    this.avatarRef,
    this.canInvite = false,
  });
  final String id;
  final String name;
  final String about;
  final String? avatarRef;
  final bool canInvite;
  bool get isGroup => id.startsWith('grp');

  factory PeerProfile.fromPublic(
    String id,
    Map<String, dynamic> value, {
    bool canInvite = false,
  }) {
    final photo = value['photo'];
    String? ref;
    if (photo is Map) {
      ref = photo['ref'] as String?;
      if (ref == null && photo['data'] is String) {
        final type = photo['type']?.toString() ?? 'jpeg';
        ref =
            'data:${type.contains('/') ? type : 'image/$type'};base64,${photo['data']}';
      }
    }
    return PeerProfile(
      id: id,
      name: value['fn']?.toString() ?? id,
      about: value['note']?.toString() ?? '',
      avatarRef: ref,
      canInvite: canInvite,
    );
  }
}
