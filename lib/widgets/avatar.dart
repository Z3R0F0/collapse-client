import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../src/data/media/media_repository.dart';

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    required this.media,
    this.ref,
    this.radius = 22,
  });
  final String name;
  final String? ref;
  final double radius;
  final MediaRepository media;
  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();
    final fallback = Center(
      child: Text(initial, style: context.textStyles.titleMedium),
    );
    if (ref == null || ref!.isEmpty) return _frame(context, fallback);
    return FutureBuilder<Uint8List>(
      future: media.bytes(ref!),
      builder: (context, snapshot) => _frame(
        context,
        snapshot.hasData
            ? Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }

  Widget _frame(BuildContext context, Widget child) {
    final corners = BorderRadius.circular(context.collapseTheme.radius);
    return Semantics(
      image: true,
      label: name,
      excludeSemantics: true,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.colors.surfaceContainer,
          borderRadius: corners,
        ),
        foregroundDecoration: BoxDecoration(
          border: Border.all(color: context.colors.outlineVariant),
          borderRadius: corners,
        ),
        child: child,
      ),
    );
  }
}
