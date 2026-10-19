import 'package:intl/intl.dart';

String formatClock(DateTime t) => DateFormat.Hm().format(t.toLocal());

String formatRelative(DateTime t, String locale) {
  final now = DateTime.now();
  final local = t.toLocal();
  final diff = now.difference(local);
  final vi = locale == 'vi';
  if (diff.inSeconds < 60) return vi ? 'Vừa xong' : 'Just now';
  if (diff.inMinutes < 60) return vi ? '${diff.inMinutes} phút' : '${diff.inMinutes}m';
  if (diff.inHours < 24 && now.day == local.day) return DateFormat.Hm().format(local);
  if (diff.inDays < 7) return DateFormat.E(locale).format(local);
  return DateFormat('dd/MM/yy').format(local);
}

String formatCountdown(Duration d) {
  final s = d.inSeconds.clamp(0, 99 * 60);
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}
