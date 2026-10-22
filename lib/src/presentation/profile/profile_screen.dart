import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import '../../../core/theme.dart';
import '../../../widgets/avatar.dart';
import '../../data/media/media_repository.dart';
import '../../data/profile/profile_repository.dart';
import '../app/settings_cubit.dart';
import '../contacts/contacts_cubit.dart';
import 'profile_cubit.dart';
import '../media/media_atlas.dart';

part 'parts/profile_editing.dart';
part 'parts/profile_invitation.dart';
part 'parts/profile_header.dart';
part 'parts/profile_members.dart';
part 'parts/profile_preferences.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.userId,
    required this.isMe,
    this.onChat,
    this.onSignOut,
    this.onNotifications,
    this.onPeerProfile,
    this.mediaTopic,
  });
  final String userId;
  final bool isMe;
  final VoidCallback? onChat;
  final VoidCallback? onSignOut;
  final VoidCallback? onNotifications;
  final ValueChanged<PeerProfile>? onPeerProfile;
  final String? mediaTopic;

  @override
  Widget build(BuildContext context) => BlocBuilder<ProfileCubit, ProfileState>(
    builder: (context, state) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ..._buildHeader(context, state),
                      if (state.loading) const LinearProgressIndicator(),
                      if (state.error != null)
                        TextButton(
                          onPressed: () => context.read<ProfileCubit>().load(),
                          child: Text(context.l10n.retry),
                        ),
                      const SizedBox(height: 16),
                      if (!isMe)
                        FilledButton.icon(
                          onPressed: onChat,
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: Text(context.l10n.startChat),
                        ),
                      ..._buildGroupMembers(context, state),
                      ..._buildOwnActions(context, state),
                    ],
                  ),
                ),
              ),
              if (mediaTopic != null)
                MediaAtlas(key: ValueKey(mediaTopic), topic: mediaTopic!),
            ],
          ),
        ),
      );
    },
  );
}
