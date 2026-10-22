import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/link.dart';

import '../../../core/theme.dart';
import '../../../widgets/avatar.dart';
import '../../data/media/media_repository.dart';

/// The full row and compact avatar share one destination and accessible label.
class PeerTile extends StatelessWidget {
  const PeerTile({
    super.key,
    required this.name,
    required this.location,
    this.preview = '',
    this.avatar,
    this.unread = 0,
    this.compact = false,
    this.selected = false,
    this.trailing,
  });
  final String name;
  final String location;
  final String preview;
  final String? avatar;
  final int unread;
  final bool compact;
  final bool selected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = unread > 0
        ? '$name, ${context.l10n.newMessages(unread)}'
        : name;
    final picture = Avatar(
      name: name,
      ref: avatar,
      media: context.read<MediaRepository>(),
    );
    return Link(
      uri: Uri.parse(location),
      builder: (context, follow) {
        // Link owns Router dispatch and web modifier/default actions. These
        // section links use canonical-parent Back, like a direct URL.
        return Semantics(
          link: true,
          child: compact
              ? Tooltip(
                  message: label,
                  child: Semantics(
                    label: label,
                    selected: selected,
                    button: true,
                    onTap: follow,
                    child: ExcludeSemantics(
                      child: Material(
                        color: selected
                            ? context.colors.surfaceContainerHighest
                            : Colors.transparent,
                        child: InkWell(
                          onTap: follow,
                          child: SizedBox(
                            height: 68,
                            child: Center(
                              child: Badge(
                                isLabelVisible: unread > 0,
                                label: Text('$unread'),
                                child: picture,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : ListTile(
                  selected: selected,
                  selectedTileColor: context.colors.surfaceContainerHighest,
                  leading: picture,
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.bodyLarge?.copyWith(
                      fontWeight: unread > 0
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                  subtitle: Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: unread > 0
                      ? Semantics(
                          label: context.l10n.newMessages(unread),
                          child: ExcludeSemantics(
                            child: Text(
                              '$unread',
                              style: context.textStyles.labelMedium?.copyWith(
                                color: context.colors.primary,
                              ),
                            ),
                          ),
                        )
                      : trailing,
                  onTap: follow,
                ),
        );
      },
    );
  }
}
