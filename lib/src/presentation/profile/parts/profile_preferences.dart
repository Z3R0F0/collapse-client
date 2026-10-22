part of '../profile_screen.dart';

extension _ProfilePreferences on ProfileScreen {
  List<Widget> _buildOwnActions(BuildContext context, ProfileState state) {
    return [
      if (isMe) ...[
        OutlinedButton.icon(
          onPressed: state.loading ? null : () => _editProfile(context, state),
          icon: const Icon(Icons.edit_outlined),
          label: Text(context.l10n.editProfile),
        ),
        TextButton(
          onPressed: state.loading ? null : () => _changePhoto(context, state),
          child: Text(context.l10n.changePhoto),
        ),
        const Divider(height: 32),
        BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, settings) => Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.l10n.language,
                  style: context.textStyles.labelSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                subtitle: DropdownButton<String>(
                  isExpanded: true,
                  value: settings.locale?.languageCode ?? '',
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(context.l10n.systemLanguage),
                    ),
                    DropdownMenuItem(
                      value: 'en',
                      child: Text(context.l10n.english),
                    ),
                    DropdownMenuItem(
                      value: 'ru',
                      child: Text(context.l10n.russian),
                    ),
                  ],
                  onChanged: (value) => context.read<SettingsCubit>().setLocale(
                    value == '' ? null : value,
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.l10n.theme,
                  style: context.textStyles.labelSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                subtitle: DropdownButton<ThemeMode>(
                  isExpanded: true,
                  value: settings.theme,
                  items: [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text(context.l10n.systemTheme),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text(context.l10n.lightTheme),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text(context.l10n.darkTheme),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      context.read<SettingsCubit>().setTheme(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_outlined),
          title: Text(context.l10n.enableNotifications),
          onTap: onNotifications,
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout),
          label: Text(context.l10n.signOut),
        ),
      ],
    ];
  }
}
