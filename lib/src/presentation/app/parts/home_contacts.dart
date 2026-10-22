part of '../home_screen.dart';

extension _HomeContacts on _HomeScreenState {
  Widget _buildContacts(BuildContext context, {bool compact = false}) => Column(
    children: [
      Offstage(
        offstage: compact,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            key: const Key('contact-search'),
            decoration: InputDecoration(
              hintText: context.l10n.search,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: _contacts.search,
          ),
        ),
      ),
      Expanded(
        child: BlocBuilder<ContactsCubit, ContactsState>(
          builder: (context, state) {
            final contacts = state.query.isEmpty
                ? context
                      .watch<ChatsCubit>()
                      .state
                      .where(
                        (topic) => !topic.isGroup && topic.id.startsWith('usr'),
                      )
                      .map(
                        (topic) => PeerProfile(
                          id: topic.id,
                          name: topic.title,
                          avatarRef: topic.avatarRef,
                        ),
                      )
                      .toList()
                : state.contacts;
            if (state.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null) {
              return Center(child: Text(context.l10n.connectionError));
            }
            if (contacts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    state.query.isEmpty
                        ? context.l10n.emptyContacts
                        : context.l10n.noResults,
                  ),
                ),
              );
            }
            return ListView.separated(
              key: const PageStorageKey('contacts-list'),
              itemCount: contacts.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, indent: compact ? 16 : 76, endIndent: 16),
              itemBuilder: (context, index) {
                final profile = contacts[index];
                return PeerTile(
                  key: ValueKey(profile.id),
                  name: profile.name,
                  avatar: profile.avatarRef,
                  preview: profile.id,
                  compact: compact,
                  selected:
                      widget.uri.pathSegments.elementAtOrNull(1) == profile.id,
                  location: AppRoutes.contact(profile.id),
                  trailing: IconButton(
                    tooltip: context.l10n.message,
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: () => _openChat(profile.id, profile.name),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}
