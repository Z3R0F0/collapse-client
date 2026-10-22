part of 'chat_screen.dart';

extension _ChatComposer on _ChatScreenState {
  void _error({bool tooLarge = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tooLarge
              ? context.l10n.attachmentTooLarge
              : context.l10n.operationError,
        ),
      ),
    );
  }

  Widget _buildComposer(BuildContext context) => ui.Composer(
    key: _composer,
    sendOnEnter: kIsWeb,
    inputClearMode: ui.InputClearMode.never,
    sigmaX: 0,
    sigmaY: 0,
    backgroundColor: context.colors.surface,
    inputFillColor: context.colors.surfaceContainerLow,
    inputBorder: Theme.of(context).inputDecorationTheme.border,
    hintColor: context.colors.onSurfaceVariant,
    textColor: context.colors.onSurface,
    sendIconColor: context.colors.primary,
    emptyFieldSendIconColor: context.colors.onSurfaceVariant,
    attachmentIconColor: context.colors.onSurfaceVariant,
    sendIcon: Icon(Icons.send, semanticLabel: context.l10n.send),
    attachmentIcon: Icon(
      Icons.attach_file,
      semanticLabel: context.l10n.attachment,
    ),
    textEditingController: _input,
    hintText: context.l10n.messageHint,
    topWidget: _recording
        ? ListTile(
            title: Text(context.l10n.recording),
            trailing: IconButton(
              tooltip: context.l10n.stopRecording,
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: _stopRecording,
            ),
          )
        : _reply == null
        ? null
        : ListTile(
            dense: true,
            title: Text(context.l10n.replying),
            subtitle: Text(
              _reply!.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: context.l10n.cancel,
              onPressed: () => _update(() {
                _draftRevision++;
                _reply = null;
              }),
              icon: const Icon(Icons.close),
            ),
          ),
  );
}
