part of 'auth_screen.dart';

extension _AuthFields on _AuthScreenState {
  List<Widget> _buildFields(BuildContext context, SessionState state) => [
    TextFormField(
      key: const Key('auth-username'),
      controller: _username,
      enabled: !state.busy,
      autofillHints: const [AutofillHints.username],
      autocorrect: false,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: context.l10n.username,
        helperText: context.l10n.usernameHint,
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      validator: (value) =>
          value == null || value.trim().length < 4 || value.trim().length > 32
          ? context.l10n.usernameHint
          : null,
    ),
    const SizedBox(height: 16),
    TextFormField(
      key: const Key('auth-password'),
      controller: _password,
      enabled: !state.busy,
      obscureText: true,
      autofillHints: [
        if (_register) AutofillHints.newPassword else AutofillHints.password,
      ],
      textInputAction: _register ? TextInputAction.next : TextInputAction.done,
      decoration: InputDecoration(
        labelText: context.l10n.password,
        helperText: context.l10n.passwordHint,
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      onFieldSubmitted: _register ? null : (_) => _submit(),
      validator: (value) =>
          value == null || value.length < 8 ? context.l10n.passwordHint : null,
    ),
    if (_register) ...[
      const SizedBox(height: 16),
      TextFormField(
        key: const Key('auth-name'),
        controller: _name,
        enabled: !state.busy,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: context.l10n.displayName,
          errorMaxLines: 3,
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? context.l10n.displayName
            : null,
      ),
    ],
  ];
}
