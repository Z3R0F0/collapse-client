import '../../data/profile/profile_repository.dart';

class ProfileState {
  const ProfileState({
    this.profile,
    this.members = const [],
    this.loading = false,
    this.error,
  });
  final PeerProfile? profile;
  final List<PeerProfile> members;
  final bool loading;
  final Object? error;
}
