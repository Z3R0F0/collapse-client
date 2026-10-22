part of 'chat_screen.dart';

extension _ChatAttachments on _ChatScreenState {
  Future<void> _upload(
    Uint8List bytes,
    String name,
    String mime,
    String type, {
    int? duration,
  }) async {
    if (!mounted || _cubit.isClosed) return;
    if (bytes.length > MediaRepository.maxBytes) {
      _error(tooLarge: true);
      return;
    }
    final session = _repository.sessionGeneration;
    final media = type == 'VD' ? context.read<MediaRepository>() : null;
    final dimensions = type == 'IM' ? await imageDimensions(bytes) : null;
    final thumbnail = type == 'IM' ? await imageThumbnail(bytes) : null;
    final video = media == null
        ? null
        : await videoMetadata(bytes, mime, media);
    if (!mounted ||
        _cubit.isClosed ||
        _repository.currentUserId != widget.userId ||
        _repository.sessionGeneration != session) {
      return;
    }
    final content = DraftyCodec.media(
      type: type,
      ref: '',
      name: name,
      mime: mime,
      size: bytes.length,
      duration: duration ?? video?.duration,
      width: dimensions?.width ?? video?.width,
      height: dimensions?.height ?? video?.height,
      thumbnail: thumbnail,
    );
    await _cubit.send(
      content,
      uploads: [
        PendingUpload(entityIndex: 0, bytes: bytes, name: name, mime: mime),
      ],
    );
  }

  Future<void> _attach() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in [
              ('photo', Icons.photo_outlined, context.l10n.photo),
              ('camera', Icons.camera_alt_outlined, context.l10n.camera),
              ('video', Icons.videocam_outlined, context.l10n.video),
              ('file', Icons.attach_file, context.l10n.file),
              ('audio', Icons.mic_none, context.l10n.record),
              ('sticker', Icons.emoji_emotions_outlined, context.l10n.sticker),
            ])
              ListTile(
                leading: Icon(item.$2),
                title: Text(item.$3),
                onTap: () => Navigator.pop(context, item.$1),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    try {
      if (choice == 'audio') {
        await _startRecording();
        return;
      }
      if (choice == 'camera') {
        final image = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
          maxWidth: 2048,
        );
        if (image != null) {
          final bytes = await image.readAsBytes();
          await _upload(
            bytes,
            image.name,
            attachmentMime(image.name, bytes) ?? 'image/jpeg',
            'IM',
          );
        }
        return;
      }
      final result = await FilePicker.pickFiles(
        withData: false,
        withReadStream: true,
        type: choice == 'photo' || choice == 'sticker'
            ? FileType.image
            : choice == 'video'
            ? FileType.video
            : FileType.any,
      );
      if (result == null || !mounted || _cubit.isClosed) return;
      final file = result.files.single;
      final stream = file.readStream;
      if (stream == null) throw StateError('Missing attachment stream');
      final bytes = await readAttachmentBytes(
        stream,
        declaredSize: file.size,
        maxBytes: MediaRepository.maxBytes,
      );
      final mime =
          attachmentMime(file.name, bytes) ?? 'application/octet-stream';
      await _upload(
        bytes,
        file.name,
        mime,
        choice == 'file'
            ? 'EX'
            : choice == 'video'
            ? 'VD'
            : 'IM',
      );
    } on AttachmentTooLarge {
      _error(tooLarge: true);
    } catch (_) {
      _error();
    }
  }
}
