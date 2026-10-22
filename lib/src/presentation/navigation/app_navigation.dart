import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';
import '../../domain/chat/media_models.dart';

/// Standard router destinations plus one serializable return hint. No second
/// route stack: browser Back/Forward remain owned by the browser and GoRouter.
abstract final class AppNavigation {
  static void media(
    BuildContext context,
    MediaItem item, {
    String surface = 'chat',
  }) {
    final uri = GoRouterState.of(context).uri;
    final location = AppRoutes.withTarget(
      Uri.parse(
        AppRoutes.media(
          item.topicId,
          seq: item.seq,
          entity: item.entityIndex,
          pending: item.pending ? item.messageId : null,
          fromInfo: surface == 'atlas',
          kind: item.category.name,
        ),
      ),
      message: int.tryParse(uri.queryParameters['message'] ?? ''),
      local: uri.queryParameters['local'],
    );
    context.go(
      location,
      extra: {
        'returnTo': AppRoutes.safeDestination(uri.toString()),
        'media': item.toJson(),
      },
    );
  }

  static void open(BuildContext context, String location) {
    final current = GoRouterState.of(context).uri.toString();
    if (current == location) return;
    context.go(
      location,
      extra: {'returnTo': AppRoutes.safeDestination(current)},
    );
  }

  static void replace(BuildContext context, String location) {
    final extra = GoRouterState.of(context).extra;
    Router.neglect(context, () => context.go(location, extra: extra));
  }

  static void back(
    BuildContext context, {
    required String fallback,
    bool exact = false,
  }) {
    final state = GoRouterState.of(context);
    final extra = state.extra;
    final value = extra is Map ? extra['returnTo'] : null;
    final previous = value is String ? AppRoutes.safeDestination(value) : null;
    final known =
        previous != null &&
        (!exact || Uri.parse(previous).path == Uri.parse(fallback).path);
    if (kIsWeb && known && urlStrategy != null) {
      // A plain router pop reports a new URL and can append another browser
      // entry. Traverse the known entry instead; a direct link has no hint.
      unawaited(urlStrategy!.go(-1));
    } else if (!kIsWeb && !known && context.canPop()) {
      context.pop();
    } else {
      Router.neglect(context, () => context.go(known ? previous : fallback));
    }
  }
}
