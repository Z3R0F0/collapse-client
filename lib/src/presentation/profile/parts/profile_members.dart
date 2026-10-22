part of '../profile_screen.dart';

extension _ProfileMembers on ProfileScreen {
  List<Widget> _buildGroupMembers(BuildContext context, ProfileState state) {
    final profile = state.profile;
    return [
      if (profile?.isGroup ?? false) ...[
        const Divider(height: 32),
        ListTile(
          title: Text(context.l10n.members),
          trailing: profile!.canInvite
              ? IconButton(
                  key: const Key('add-member'),
                  tooltip: context.l10n.addMember,
                  icon: const Icon(Icons.person_add_outlined),
                  onPressed: state.loading
                      ? null
                      : () => _inviteMember(context, state),
                )
              : null,
        ),
        ...state.members.map(
          (peer) => ListTile(
            leading: Avatar(
              name: peer.name,
              ref: peer.avatarRef,
              media: context.read<MediaRepository>(),
            ),
            title: Text(peer.name),
            subtitle: Text(peer.id),
            onTap: onPeerProfile == null ? null : () => onPeerProfile!(peer),
          ),
        ),
      ],
    ];
  }
}
