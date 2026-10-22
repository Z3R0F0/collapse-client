import '../../data/profile/profile_repository.dart';

class ContactsState {
  const ContactsState({
    this.contacts = const [],
    this.loading = false,
    this.error,
    this.query = '',
  });
  final List<PeerProfile> contacts;
  final bool loading;
  final Object? error;
  final String query;
}
