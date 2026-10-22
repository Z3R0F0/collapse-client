part of '../home_screen.dart';

extension _HomeNavigation on _HomeScreenState {
  void _openChat(String id, String title) {
    if (mounted) AppNavigation.open(context, AppRoutes.chat(id));
  }

  Widget _buildNavigation(BuildContext context) => DecoratedBox(
    position: DecorationPosition.foreground,
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.colors.outlineVariant)),
    ),
    child: NavigationBar(
      animationDuration: const Duration(milliseconds: 140),
      selectedIndex: _tab,
      onDestinationSelected: _selectTab,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.chat_bubble_outline),
          label: context.l10n.chats,
        ),
        NavigationDestination(
          icon: const Icon(Icons.people_outline),
          label: context.l10n.contacts,
        ),
        NavigationDestination(
          icon: const Icon(Icons.person_outline),
          label: context.l10n.profile,
        ),
      ],
    ),
  );

  Widget _buildCompactNavigation(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (index, icon, label) in [
        (0, Icons.chat_bubble_outline, context.l10n.chats),
        (1, Icons.people_outline, context.l10n.contacts),
        (2, Icons.person_outline, context.l10n.profile),
      ])
        IconButton(
          tooltip: label,
          isSelected: _tab == index,
          color: _tab == index ? context.colors.primary : null,
          onPressed: () => _selectTab(index),
          icon: Icon(icon),
        ),
    ],
  );
}
