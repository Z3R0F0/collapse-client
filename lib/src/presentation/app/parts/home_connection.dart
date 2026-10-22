part of '../home_screen.dart';

extension _HomeConnection on _HomeScreenState {
  Widget _buildConnection(BuildContext context) =>
      BlocConsumer<AuthCubit, SessionState>(
        listenWhen: (previous, current) =>
            previous.phase != SessionPhase.online &&
            current.phase == SessionPhase.online &&
            current.userId == widget.userId,
        listener: (_, _) => _profile.load(),
        builder: (context, session) => session.phase == SessionPhase.online
            ? const SizedBox.shrink()
            : Material(
                color: context.colors.surfaceContainerLow,
                child: InkWell(
                  onTap: context.read<AuthCubit>().reconnect,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: context.colors.outlineVariant,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.offline,
                            style: context.textStyles.labelMedium,
                          ),
                        ),
                        const Icon(Icons.refresh, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
      );
}
