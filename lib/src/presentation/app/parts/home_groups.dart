part of '../home_screen.dart';

extension _HomeGroups on _HomeScreenState {
  Future<void> _createGroup() async {
    final name = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.newGroup),
        content: TextField(
          controller: name,
          maxLength: 80,
          decoration: InputDecoration(labelText: context.l10n.groupName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) Navigator.pop(context, true);
            },
            child: Text(context.l10n.create),
          ),
        ],
      ),
    );
    try {
      if (accepted == true) {
        final id = await _chats.createGroup(name.text);
        if (mounted) _openChat(id, name.text);
      }
    } catch (_) {
      _showError();
    }
    name.dispose();
  }
}
