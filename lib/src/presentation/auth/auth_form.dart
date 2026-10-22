part of 'auth_screen.dart';

extension _AuthForm on _AuthScreenState {
  Widget _buildForm(BuildContext context, SessionState state) => AutofillGroup(
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n.appName, style: context.textStyles.displaySmall),
          const SizedBox(height: 12),
          Text(
            context.l10n.authHint,
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Divider(height: 1),
          ),
          Text(
            _register ? context.l10n.register : context.l10n.signIn,
            style: context.textStyles.titleLarge,
          ),
          const SizedBox(height: 20),
          if (widget.config.apiKey.isEmpty)
            Text(
              context.l10n.missingConfig,
              style: TextStyle(color: context.colors.error),
            ),
          ..._buildFields(context, state),
          const SizedBox(height: 20),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                context.l10n.authError,
                style: TextStyle(color: context.colors.error),
              ),
            ),
          FilledButton(
            key: const Key('auth-submit'),
            onPressed: state.busy || widget.config.apiKey.isEmpty
                ? null
                : _submit,
            child: state.busy
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.onSurfaceVariant,
                    ),
                  )
                : Text(_register ? context.l10n.register : context.l10n.signIn),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: state.busy ? null : _toggleMode,
            child: Text(
              _register ? context.l10n.signIn : context.l10n.register,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${context.l10n.server}: ${widget.config.endpoint.authority}',
            style: context.textStyles.labelSmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
