/// Date, time and duration formatting used across the app.
abstract final class Fmt {
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String two(int n) => n.toString().padLeft(2, '0');

  static String time(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
  static String timeSec(DateTime d) => '${time(d)}:${two(d.second)}';
  static String dateShort(DateTime d) => '${_months[d.month - 1]} ${d.day}';
  static String dateFull(DateTime d) => '${dateShort(d)}, ${d.year} · ${time(d)}';

  /// "Today, 02:14" / "Yesterday, 02:14" / "Nov 3, 02:14"
  static String dateTime(DateTime d) {
    final now = DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today, ${time(d)}';
    if (diff == 1) return 'Yesterday, ${time(d)}';
    return '${dateShort(d)}, ${time(d)}';
  }

  /// "48s", "1m04s", "1h02m"
  static String duration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h${two(d.inMinutes % 60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m${two(d.inSeconds % 60)}s';
    return '${d.inSeconds}s';
  }

  /// "04:59" stopwatch style.
  static String clock(Duration d) {
    final h = d.inHours;
    final mmss = '${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
    return h > 0 ? '$h:$mmss' : mmss;
  }

  /// Offset in a timeline: "+0.07s", "+40s", "+2m10s".
  static String offset(Duration d) {
    if (d.inMilliseconds < 1000) return '+${(d.inMilliseconds / 1000).toStringAsFixed(2)}s';
    return '+${duration(d)}';
  }

  static String ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static String num0(double v) => v.round().toString();
}
