import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({
    required this.endpoint,
    required this.apiKey,
    Uri? transportEndpoint,
  }) : _transportEndpoint = transportEndpoint;

  factory AppConfig.environment() {
    const host = String.fromEnvironment(
      'TINODE_HOST',
      defaultValue: '127.0.0.1:6060',
    );
    const tls = bool.fromEnvironment('TINODE_TLS', defaultValue: false);
    if (kReleaseMode && (!tls || (kIsWeb && Uri.base.scheme != 'https'))) {
      throw StateError('Release builds require TLS for server and transport.');
    }
    return AppConfig(
      endpoint: Uri.parse('${tls ? 'wss' : 'ws'}://$host/v0/channels'),
      apiKey: const String.fromEnvironment('TINODE_API_KEY'),
      // Browsers reach stock Tinode through the same-origin /v0/ proxy.
      // Keep the configured endpoint as the durable account/cache identity.
      transportEndpoint: kIsWeb
          ? Uri(
              scheme: Uri.base.scheme == 'https' ? 'wss' : 'ws',
              host: Uri.base.host,
              port: Uri.base.hasPort ? Uri.base.port : null,
              path: '/v0/channels',
            )
          : null,
    );
  }

  final Uri endpoint;
  final String apiKey;
  final Uri? _transportEndpoint;
  Uri get transportEndpoint => _transportEndpoint ?? endpoint;
  String get serverId => endpoint.replace(query: '').toString();
  Uri get httpBase => _httpBase(transportEndpoint);
  Uri get canonicalHttpBase => _httpBase(endpoint);

  static Uri _httpBase(Uri endpoint) => Uri(
    scheme: {'wss', 'https'}.contains(endpoint.scheme) ? 'https' : 'http',
    host: endpoint.host,
    port: endpoint.hasPort ? endpoint.port : null,
    path: '/',
  );
}
