/// URLs contain identifiers and navigation intent, never cached models or auth.
abstract final class AppRoutes {
  static const chats = '/chats';
  static const contacts = '/contacts';
  static const profile = '/profile';
  static const login = '/login';

  static bool isTopic(String value) =>
      RegExp(r'^(usr|grp|chn)[A-Za-z0-9_-]+$').hasMatch(value);

  static String chat(String topic, {int? message, String? local}) => Uri(
    path: '$chats/${Uri.encodeComponent(topic)}',
    queryParameters: message != null && message > 0
        ? {'message': '$message'}
        : local != null
        ? {'local': local}
        : null,
  ).toString();

  static String info(String topic, {String? member}) => Uri(
    path: '${chat(topic)}/info',
    queryParameters: member == null ? null : {'member': member},
  ).toString();

  static String search(String topic, {String query = ''}) => Uri(
    path: '${chat(topic)}/search',
    queryParameters: query.isEmpty ? null : {'q': query},
  ).toString();

  static String contact(String id) => '$contacts/${Uri.encodeComponent(id)}';

  static String media(
    String topic, {
    required int seq,
    required int entity,
    String? pending,
    bool fromInfo = false,
    String kind = 'visual',
  }) => Uri(
    path: '${fromInfo ? info(topic) : chat(topic)}/media',
    queryParameters: {
      if (seq > 0) 'seq': '$seq',
      if (seq <= 0 && pending != null) 'pending': pending,
      'entity': '$entity',
      'kind': kind,
    },
  ).toString();

  static String withTarget(Uri uri, {int? message, String? local}) {
    final query = Map<String, String>.of(uri.queryParameters)
      ..remove('message')
      ..remove('local');
    if (message != null && message > 0) {
      query['message'] = '$message';
    } else if (local != null && local.isNotEmpty && local.length <= 128) {
      query['local'] = local;
    }
    return Uri(
      path: uri.path,
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  static String _keepTarget(String location, Uri source) => withTarget(
    Uri.parse(location),
    message: int.tryParse(source.queryParameters['message'] ?? ''),
    local: source.queryParameters['local'],
  );

  /// Only application-owned destinations may survive an authentication handoff.
  static String safeDestination(String? value) {
    try {
      return _destination(value);
    } on FormatException {
      return chats;
    }
  }

  static String _destination(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null || uri.hasScheme || uri.hasAuthority || uri.hasFragment) {
      return chats;
    }
    final parts = uri.pathSegments;
    if (uri.path == chats || uri.path == contacts || uri.path == profile) {
      return uri.path;
    }
    if (parts.length >= 2 && isTopic(parts[1])) {
      if (parts[0] == 'contacts' && parts.length == 2) return contact(parts[1]);
      if (parts[0] == 'chats') {
        final isMedia =
            (parts.length == 3 && parts[2] == 'media') ||
            (parts.length == 4 && parts[2] == 'info' && parts[3] == 'media');
        if (isMedia) {
          final seq = int.tryParse(uri.queryParameters['seq'] ?? '') ?? 0;
          final key = int.tryParse(uri.queryParameters['entity'] ?? '') ?? -1;
          final pending = uri.queryParameters['pending'];
          final kind = uri.queryParameters['kind'];
          if (key < 0 ||
              key > 10000 ||
              (seq <= 0 &&
                  (pending == null ||
                      pending.isEmpty ||
                      pending.length > 128))) {
            return parts.length == 4 ? info(parts[1]) : chat(parts[1]);
          }
          return _keepTarget(
            media(
              parts[1],
              seq: seq,
              entity: key,
              pending: pending,
              fromInfo: parts.length == 4,
              kind: const {'visual', 'audio', 'files'}.contains(kind)
                  ? kind!
                  : 'visual',
            ),
            uri,
          );
        }
        if (parts.length == 2) {
          final local = uri.queryParameters['local'];
          return chat(
            parts[1],
            message: int.tryParse(uri.queryParameters['message'] ?? ''),
            local: local != null && local.length <= 128 ? local : null,
          );
        }
        if (parts.length == 3 && parts[2] == 'info') {
          final member = uri.queryParameters['member'];
          return _keepTarget(
            info(
              parts[1],
              member: member != null && isTopic(member) ? member : null,
            ),
            uri,
          );
        }
        if (parts.length == 3 && parts[2] == 'search') {
          final query = uri.queryParameters['q'] ?? '';
          return _keepTarget(
            search(parts[1], query: query.length <= 256 ? query : ''),
            uri,
          );
        }
      }
    }
    return chats;
  }
}
