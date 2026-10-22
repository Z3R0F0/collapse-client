part of '../profile_screen.dart';

extension _ProfileHeader on ProfileScreen {
  List<Widget> _buildHeader(BuildContext context, ProfileState state) {
    final profile = state.profile;
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: Avatar(
          name: profile?.name ?? userId,
          ref: profile?.avatarRef,
          radius: 32,
          media: context.read<MediaRepository>(),
        ),
      ),
      const SizedBox(height: 20),
      Text(profile?.name ?? userId, style: context.textStyles.headlineSmall),
      const SizedBox(height: 6),
      SelectableText(
        userId,
        style: context.textStyles.labelSmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
      if (profile?.about.isNotEmpty ?? false)
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 4),
          child: Text(profile!.about),
        ),
    ];
  }
}
