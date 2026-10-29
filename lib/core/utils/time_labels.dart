String timeAgo(DateTime? value) {
  if (value == null) return 'Not available';
  final delta = DateTime.now().difference(value);
  if (delta.inSeconds < 60) return 'just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
  if (delta.inHours < 24) return '${delta.inHours} hr ago';
  return '${delta.inDays} days ago';
}
