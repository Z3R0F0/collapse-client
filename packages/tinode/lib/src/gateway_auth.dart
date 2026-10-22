part of 'tinode_gateway.dart';

extension _GatewayAuth on TinodeGateway {
  Future<JsonMap> _authenticate(String kind, JsonMap payload) async {
    final response = await _request(kind, payload);
    final code = response['code'] as int? ?? 500;
    if (code >= 200 && code < 300) {
      final params = response['params'] as Map? ?? {};
      userId = params['user'] as String?;
      token = params['token'] as String?;
    }
    // 3xx credential-validation challenges remain explicit to the caller.
    return response;
  }

  Future<JsonMap> _loginBasic(String username, String password) =>
      _authenticate('login', {
        'scheme': 'basic',
        'secret': base64Encode(utf8.encode('$username:$password')),
      });
  Future<JsonMap> _loginToken(String value) =>
      _authenticate('login', {'scheme': 'token', 'secret': value});

  /// Standard Tinode device registration; U+2421 clears this session's device.
  Future<void> _setDeviceToken(String? value) async {
    if (userId == null) {
      throw const TinodeException(401, 'Authentication required');
    }
    await _request(
        'hi', {'dev': value == null || value.isEmpty ? '\u2421' : value});
  }

  Future<JsonMap> _createAccountBasic(String username, String password,
          {required JsonMap public}) =>
      _authenticate('acc', {
        'user': 'new',
        'scheme': 'basic',
        'login': true,
        'secret': base64Encode(utf8.encode('$username:$password')),
        'desc': {'public': public},
      });
}
