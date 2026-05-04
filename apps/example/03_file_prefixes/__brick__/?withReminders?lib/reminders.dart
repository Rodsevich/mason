// `?withReminders?` prefix: only generated when the boolean variable
// `withReminders` is truthy. Skipped silently otherwise.

class Reminder {
  const Reminder({required this.taskId, required this.remindAt});
  final String taskId;
  final DateTime remindAt;
}
