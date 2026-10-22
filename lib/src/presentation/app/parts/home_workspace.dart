part of '../home_screen.dart';

extension _HomeWorkspace on _HomeScreenState {
  Widget _buildMaster(BuildContext context, bool compact) {
    final wide = MediaQuery.sizeOf(context).width >= WorkspaceLayout.breakpoint;
    return Material(
      color: context.colors.surfaceContainerLow,
      child: Column(
        children: [
          SizedBox(
            height: kToolbarHeight,
            child: Row(
              children: [
                if (wide)
                  IconButton(
                    tooltip: compact
                        ? context.l10n.expandSidebar
                        : context.l10n.collapseSidebar,
                    onPressed: () => context
                        .read<SettingsCubit>()
                        .setSidebarWidth(compact ? 320 : 72),
                    icon: Icon(
                      compact ? Icons.chevron_right : Icons.chevron_left,
                    ),
                  ),
                if (!compact) ...[
                  if (!wide) const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '${context.l10n.appName} / ${_tab == 1 ? context.l10n.contacts : context.l10n.chats}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.newGroup,
                    onPressed: _createGroup,
                    icon: const Icon(Icons.group_add_outlined, size: 20),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: IndexedStack(
              index: _tab == 1 ? 1 : 0,
              children: [
                ViewActivity(
                  active: _tab != 1,
                  child: _buildChats(context, compact: compact),
                ),
                ViewActivity(
                  active: _tab == 1,
                  child: _buildContacts(context, compact: compact),
                ),
              ],
            ),
          ),
          if (wide)
            compact
                ? _buildCompactNavigation(context)
                : _buildNavigation(context),
        ],
      ),
    );
  }
}
