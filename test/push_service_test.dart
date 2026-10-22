import 'package:collapse/core/notifications/push_service.dart';
import 'package:collapse_tinode/tinode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'standard Tinode push topics route without accepting arbitrary URLs',
    () {
      expect(pushTopic({'topic': 'grpabc_DEF-123'}), 'grpabc_DEF-123');
      expect(
        pushTopic({'topic': 'usrabc123', 'xfrom': 'usrignored'}),
        'usrabc123',
      );
      expect(pushTopic({'topic': 'me', 'xfrom': 'usrabc123'}), 'usrabc123');
      expect(pushTopic({'xfrom': 'usrabc123'}), 'usrabc123');
      expect(pushTopic({'topic': 'https://external.example'}), isNull);
      expect(pushTopic({'topic': 'sys'}), isNull);
      expect(pushTopic({'topic': 42}), isNull);
      expect(pushTopic({}), isNull);
    },
  );

  test(
    'disabled push requires neither Firebase credentials nor permissions',
    () async {
      final gateway = TinodeGateway(
        endpoint: Uri.parse('http://127.0.0.1:6060'),
        apiKey: 'unused',
      );
      final push = PushService(gateway, enabled: false);
      expect(push.configured, isFalse);
      await push.initialize(
        onOpenTopic: (_) => fail('No notification expected'),
      );
      expect(await push.enable(), isFalse);
      expect(await push.synchronize(), isFalse);
      await push.logout();
      await push.dispose();
      await gateway.dispose();
    },
  );
}
