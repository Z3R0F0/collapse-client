typedef JsonMap = Map<String, dynamic>;

class TinodeEvent {
  const TinodeEvent(this.kind, this.payload);
  final String kind;
  final JsonMap payload;
  String? get topic => payload['topic'] as String?;
  String? get id => payload['id']?.toString();
}

class TinodeException implements Exception {
  const TinodeException(this.code, this.message);
  final int code;
  final String message;
  @override
  String toString() => 'TinodeException($code): $message';
}
