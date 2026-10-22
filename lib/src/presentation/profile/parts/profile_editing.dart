part of '../profile_screen.dart';

extension _ProfileEditing on ProfileScreen {
  Future<void> _editProfile(BuildContext context, ProfileState state) async {
    final cubit = context.read<ProfileCubit>();
    final name = TextEditingController(text: state.profile?.name ?? '');
    final about = TextEditingController(text: state.profile?.about ?? '');
    final save = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(dialog.l10n.editProfile),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              maxLength: 80,
              decoration: InputDecoration(labelText: dialog.l10n.displayName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: about,
              maxLength: 256,
              decoration: InputDecoration(labelText: dialog.l10n.about),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(dialog.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) Navigator.pop(dialog, true);
            },
            child: Text(dialog.l10n.save),
          ),
        ],
      ),
    );
    if (save == true && context.mounted && !cubit.isClosed) {
      await cubit.save(name.text, about.text);
    }
    name.dispose();
    about.dispose();
  }

  Future<void> _changePhoto(BuildContext context, ProfileState state) async {
    final cubit = context.read<ProfileCubit>();
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (photo == null || !context.mounted || cubit.isClosed) return;
      final bytes = await photo.readAsBytes();
      if (!context.mounted || cubit.isClosed) return;
      if (bytes.length > MediaRepository.maxBytes) {
        throw const FormatException('Image too large');
      }
      await cubit.save(
        state.profile?.name ?? userId,
        state.profile?.about ?? '',
        photo: bytes,
        photoName: photo.name,
        photoMime:
            lookupMimeType(photo.name, headerBytes: bytes) ?? 'image/jpeg',
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.operationError)));
      }
    }
  }
}
