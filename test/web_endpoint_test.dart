import 'package:collapse/core/config.dart';
import 'package:collapse/src/data/media/media_repository.dart';
import 'package:collapse/src/data/media/web_media_cache.dart';
import 'package:collapse_tinode/tinode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final canonical = Uri.parse('ws://127.0.0.1:6060/v0/channels');
  AppConfig config([int? proxyPort]) => AppConfig(
    endpoint: canonical,
    apiKey: 'test',
    transportEndpoint: proxyPort == null
        ? null
        : Uri.parse('ws://127.0.0.1:$proxyPort/v0/channels'),
  );

  test('web proxy does not change durable account or cache identity', () {
    final direct = config();
    final proxy = config(8086);
    expect(proxy.serverId, direct.serverId);
    expect(config(8085).serverId, direct.serverId);
    expect(proxy.endpoint, canonical);
    expect(proxy.transportEndpoint.authority, '127.0.0.1:8086');
    expect(proxy.httpBase.toString(), 'http://127.0.0.1:8086/');
    expect(proxy.canonicalHttpBase.toString(), 'http://127.0.0.1:6060/');
    expect(direct.transportEndpoint, canonical);
  });

  test(
    'legacy and relative media use proxy but external URLs get no auth',
    () async {
      final proxy = config(8086);
      final gateway =
          TinodeGateway(endpoint: proxy.transportEndpoint, apiKey: 'test')
            ..userId = 'me'
            ..token = 'synthetic';
      final media = MediaRepository(proxy, gateway, cache: WebMediaCache())
        ..userId = 'me';
      addTearDown(media.dispose);
      addTearDown(gateway.dispose);
      for (final ref in [
        '/v0/file/s/a?x=1',
        'a?x=1',
        'http://127.0.0.1:6060/v0/file/s/a?x=1',
      ]) {
        final uri = media.resolve(ref);
        expect(uri.toString(), 'http://127.0.0.1:8086/v0/file/s/a?x=1');
        expect(media.headers(uri)['Authorization'], 'token synthetic');
      }
      final external = media.resolve('https://external.test/a');
      expect(external.host, 'external.test');
      expect(media.headers(external), isEmpty);
      for (final ref in [
        'http://127.0.0.1:6061/v0/file/s/a',
        'http://user:secret@127.0.0.1:6060/v0/file/s/a',
      ]) {
        expect(() => media.resolve(ref), throwsFormatException);
      }
    },
  );
}
