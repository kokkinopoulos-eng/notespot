enum TimelineBucket { today, yesterday, thisWeek, earlier }

TimelineBucket bucketFor(DateTime created, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(created.year, created.month, created.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return TimelineBucket.today;
  if (diff == 1) return TimelineBucket.yesterday;
  if (diff < 7) return TimelineBucket.thisWeek;
  return TimelineBucket.earlier;
}