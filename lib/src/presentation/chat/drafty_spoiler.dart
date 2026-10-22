import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// Layout is identical before/after reveal, including emoji and wrapped code.
/// Opacity + excluded semantics hide glyphs, not just their foreground colour.
class DraftySpoiler extends StatefulWidget {
  const DraftySpoiler({super.key, required this.child});
  final Widget child;

  @override
  State<DraftySpoiler> createState() => _DraftySpoilerState();
}

class _DraftySpoilerState extends State<DraftySpoiler> {
  bool _revealed = false;

  void _reveal() => setState(() => _revealed = true);

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      ExcludeSemantics(
        excluding: !_revealed,
        child: IgnorePointer(
          ignoring: !_revealed,
          child: AnimatedOpacity(
            opacity: _revealed ? 1 : 0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 140),
            child: widget.child,
          ),
        ),
      ),
      if (!_revealed)
        Positioned.fill(
          child: Semantics(
            container: true,
            label: context.l10n.revealSpoiler,
            button: true,
            onTap: _reveal,
            child: ExcludeSemantics(
              child: Material(
                color: context.colors.onSurfaceVariant.withValues(alpha: .25),
                borderRadius: BorderRadius.circular(
                  context.collapseTheme.radius,
                ),
                child: InkWell(
                  onTap: _reveal,
                  borderRadius: BorderRadius.circular(
                    context.collapseTheme.radius,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
