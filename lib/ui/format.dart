import 'package:intl/intl.dart';

/// Human-friendly relative time for chat rows and message stamps.
String relativeTime(int epochMs) {
  final DateTime t = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final DateTime now = DateTime.now();
  final Duration delta = now.difference(t);

  if (delta.inSeconds < 45) return 'now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m';
  if (delta.inHours < 24 && now.day == t.day) return DateFormat.jm().format(t);
  if (delta.inDays < 1) return 'Yesterday';
  if (delta.inDays < 7) return DateFormat.E().format(t); // Mon, Tue
  return DateFormat.MMMd().format(t); // Jul 25
}

/// Clock time shown inside a message bubble.
String clockTime(int epochMs) =>
    DateFormat.jm().format(DateTime.fromMillisecondsSinceEpoch(epochMs));
