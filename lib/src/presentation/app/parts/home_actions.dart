part of '../home_screen.dart';

extension _HomeActions on _HomeScreenState {
  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.signOut),
        content: Text(context.l10n.signOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.signOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final auth = context.read<AuthCubit>();
    try {
      await context.read<PushService>().logout();
    } catch (_) {
      // Local logout must succeed even when device deregistration is offline.
    } finally {
      await auth.signOut();
    }
  }

  Future<void> _enableNotifications() async {
    final push = context.read<PushService>();
    if (!push.configured) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.pushNotConfigured)));
      return;
    }
    try {
      final enabled = await push.enable();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? context.l10n.notificationsEnabled
                  : context.l10n.permissionDenied,
            ),
          ),
        );
      }
    } catch (_) {
      _showError();
    }
  }

  void _showError() {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.operationError)));
    }
  }
}
