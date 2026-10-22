part of '../profile_screen.dart';

extension _ProfileInvitation on ProfileScreen {
  Future<void> _inviteMember(BuildContext context, ProfileState state) async {
    final cubit = context.read<ProfileCubit>();
    final member = await showDialog<PeerProfile>(
      context: context,
      builder: (_) => BlocProvider(
        create: (_) => ContactsCubit(cubit.repository),
        child: Builder(
          builder: (dialog) => AlertDialog(
            title: Text(dialog.l10n.addMember),
            content: SizedBox(
              width: 360,
              height: 300,
              child: Column(
                children: [
                  TextField(
                    key: const Key('member-search'),
                    autofocus: true,
                    decoration: InputDecoration(hintText: dialog.l10n.search),
                    onChanged: dialog.read<ContactsCubit>().search,
                  ),
                  Expanded(
                    child: BlocBuilder<ContactsCubit, ContactsState>(
                      builder: (context, contacts) {
                        if (contacts.loading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (contacts.error != null) {
                          return Center(
                            child: Text(context.l10n.connectionError),
                          );
                        }
                        final candidates = contacts.contacts
                            .where(
                              (peer) => !state.members.any(
                                (member) => member.id == peer.id,
                              ),
                            )
                            .toList();
                        if (candidates.isEmpty) {
                          return Center(
                            child: Text(
                              contacts.query.isEmpty
                                  ? context.l10n.emptyContacts
                                  : context.l10n.noResults,
                            ),
                          );
                        }
                        return ListView(
                          children: candidates
                              .map(
                                (peer) => ListTile(
                                  title: Text(peer.name),
                                  subtitle: Text(peer.id),
                                  onTap: () => Navigator.pop(context, peer),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: Text(dialog.l10n.cancel),
              ),
            ],
          ),
        ),
      ),
    );
    if (member == null || cubit.isClosed) return;
    try {
      await cubit.invite(member.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.operationError)));
      }
    }
  }
}
