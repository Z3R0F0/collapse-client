/// Interval-compressed duplicate protection, scoped to one authenticated session.
/// SQLite uniqueness remains authoritative across process restarts.
class MessageSeqCache {
  final Map<String, List<List<int>>> _intervals = {};

  bool contains(String topic, int seq) =>
      _intervals[topic]?.any((r) => seq >= r[0] && seq <= r[1]) ?? false;

  void add(String topic, int seq) {
    if (seq <= 0) return;
    final ranges = _intervals.putIfAbsent(topic, () => []);
    ranges.add([seq, seq]);
    ranges.sort((a, b) => a[0].compareTo(b[0]));
    for (var i = 0; i + 1 < ranges.length;) {
      if (ranges[i + 1][0] <= ranges[i][1] + 1) {
        if (ranges[i + 1][1] > ranges[i][1]) ranges[i][1] = ranges[i + 1][1];
        ranges.removeAt(i + 1);
      } else {
        i++;
      }
    }
  }

  void clear() => _intervals.clear();
}
